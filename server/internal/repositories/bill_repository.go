package repositories

import (
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type BillRepository struct {
	db *gorm.DB
}

func NewBillRepository(db *gorm.DB) *BillRepository {
	return &BillRepository{db: db}
}

// BillGenerationRequest drives GenerateForPeriod.
type BillGenerationRequest struct {
	BillingPeriod string    // "2026-04"
	DueDate       time.Time
	// Legacy flat-rate fields (used only when no billing structure exists)
	MaintenanceCharge float64
	SinkingFund       float64
	RepairFund        float64
	WaterCharge       float64
	OtherCharges      float64
}

// flatInfo bundles member + flat data for bill calculation.
type flatInfo struct {
	MemberID uuid.UUID
	FlatID   uuid.UUID
	AreaSqft float64
	Floor    int
}

// GenerateForPeriod creates a bill for every flat that does not already have
// one for the given billing period. Uses the active BillingStructure if
// available, otherwise falls back to legacy flat-rate fields.
// Returns (billsCreated, skipped, error).
func (r *BillRepository) GenerateForPeriod(actor *ActorContext, req BillGenerationRequest) (int, int, error) {
	if !actor.IsAdmin() {
		return 0, 0, ErrForbidden
	}

	// Pull all (member, flat) with area info.
	var flats []flatInfo
	if err := r.db.Model(&models.Member{}).
		Select("members.id AS member_id, members.flat_id, flats.area_sqft, flats.floor").
		Joins("JOIN flats ON flats.id = members.flat_id").
		Where("members.flat_id IS NOT NULL AND members.is_active = ?", true).
		Scan(&flats).Error; err != nil {
		return 0, 0, err
	}

	// Try to load active billing structure + charge heads.
	var bs *models.BillingStructure
	r.db.Where("is_active = ?", true).
		Preload("ChargeHeads", func(db *gorm.DB) *gorm.DB {
			return db.Where("is_active = ?", true).Order("sort_order ASC")
		}).First(&bs)
	useStructure := bs != nil && len(bs.ChargeHeads) > 0

	issueDate := time.Now()
	created, skipped := 0, 0

	for _, f := range flats {
		// Skip if bill already exists for this flat+period
		var exists int64
		r.db.Model(&models.MaintenanceBill{}).
			Where("flat_id = ? AND billing_period = ?", f.FlatID, req.BillingPeriod).
			Count(&exists)
		if exists > 0 {
			skipped++
			continue
		}

		var bill *models.MaintenanceBill
		var lineItems []models.BillLineItem

		if useStructure {
			bill, lineItems = r.buildBillFromStructure(bs, f, req, actor.MemberID, issueDate)
		} else {
			bill = r.buildLegacyBill(f, req, actor.MemberID, issueDate)
		}

		// Calculate arrears from previous unpaid bills for this flat
		arrear, interest := r.calcArrearsAndInterest(f.FlatID, bs, req.DueDate)
		if arrear > 0 {
			bill.ArrearAmount = round2(arrear)
			bill.TotalAmount += bill.ArrearAmount
			lineItems = append(lineItems, models.BillLineItem{
				Label: "Previous Arrears", LabelMr: "मागील थकबाकी",
				Amount: bill.ArrearAmount, IsArrear: true,
			})
		}
		if interest > 0 {
			bill.InterestAmount = round2(interest)
			bill.TotalAmount += bill.InterestAmount
			lineItems = append(lineItems, models.BillLineItem{
				Label: "Interest on Overdue", LabelMr: "विलंब व्याज",
				Amount: bill.InterestAmount, IsInterest: true,
			})
		}

		bill.TotalAmount = round2(bill.TotalAmount)

		if err := r.db.Create(bill).Error; err != nil {
			return created, skipped, err
		}

		// Save line items with bill ID
		for i := range lineItems {
			lineItems[i].BillID = bill.ID
		}
		if len(lineItems) > 0 {
			if err := r.db.Create(&lineItems).Error; err != nil {
				return created, skipped, fmt.Errorf("bill line items failed: %w", err)
			}
		}

		created++
	}
	return created, skipped, nil
}

// buildBillFromStructure calculates per-flat charges from the active billing structure.
// Applies FlatChargeOverride records for differential billing (FIN-006).
func (r *BillRepository) buildBillFromStructure(
	bs *models.BillingStructure, f flatInfo, req BillGenerationRequest,
	generatedBy uuid.UUID, issueDate time.Time,
) (*models.MaintenanceBill, []models.BillLineItem) {
	bill := &models.MaintenanceBill{
		BillNo:             fmt.Sprintf("BILL-%s-%d", req.BillingPeriod, time.Now().UnixNano()%1000000),
		FlatID:             f.FlatID,
		MemberID:           f.MemberID,
		BillingPeriod:      req.BillingPeriod,
		IssueDate:          issueDate,
		DueDate:            req.DueDate,
		Status:             models.BillIssued,
		GeneratedByID:      generatedBy,
		BillingStructureID: &bs.ID,
	}

	// Load per-flat overrides keyed by charge head ID
	var overrides []models.FlatChargeOverride
	r.db.Where("flat_id = ?", f.FlatID).Find(&overrides)
	overrideMap := make(map[uuid.UUID]models.FlatChargeOverride, len(overrides))
	for _, o := range overrides {
		overrideMap[o.ChargeHeadID] = o
	}

	var total float64
	var items []models.BillLineItem

	area := f.AreaSqft
	if area <= 0 {
		area = 1200 // default sqft if not set
	}

	for _, ch := range bs.ChargeHeads {
		// Check for per-flat override
		if ov, ok := overrideMap[ch.ID]; ok {
			if ov.Exempt {
				continue // skip this charge for this flat
			}
			ch.Rate = ov.Rate // use override rate
		}

		var amount float64
		var qty float64 = 1

		switch ch.CalcMethod {
		case models.CalcPerSqft:
			amount = round2(ch.Rate * area)
			qty = area
		case models.CalcFixed:
			amount = ch.Rate
		}

		total += amount
		items = append(items, models.BillLineItem{
			ChargeHeadID: &ch.ID,
			Label:        ch.Name,
			LabelMr:      ch.NameMr,
			CalcMethod:   ch.CalcMethod,
			Rate:         ch.Rate,
			Quantity:     qty,
			Amount:       amount,
		})

		// Map to legacy summary fields for backward compat
		switch ch.SortOrder {
		case 1:
			bill.MaintenanceCharge = amount
		case 2:
			bill.SinkingFund = amount
		case 3:
			bill.RepairFund = amount
		case 4:
			bill.WaterCharge = amount
		default:
			bill.OtherCharges += amount
		}
	}

	bill.TotalAmount = round2(total)
	return bill, items
}

// buildLegacyBill uses the flat-rate fields from the request (no billing structure).
func (r *BillRepository) buildLegacyBill(
	f flatInfo, req BillGenerationRequest, generatedBy uuid.UUID, issueDate time.Time,
) *models.MaintenanceBill {
	total := req.MaintenanceCharge + req.SinkingFund + req.RepairFund +
		req.WaterCharge + req.OtherCharges
	return &models.MaintenanceBill{
		BillNo:            fmt.Sprintf("BILL-%s-%d", req.BillingPeriod, time.Now().UnixNano()%1000000),
		FlatID:            f.FlatID,
		MemberID:          f.MemberID,
		BillingPeriod:     req.BillingPeriod,
		IssueDate:         issueDate,
		DueDate:           req.DueDate,
		MaintenanceCharge: req.MaintenanceCharge,
		SinkingFund:       req.SinkingFund,
		RepairFund:        req.RepairFund,
		WaterCharge:       req.WaterCharge,
		OtherCharges:      req.OtherCharges,
		TotalAmount:       total,
		Status:            models.BillIssued,
		GeneratedByID:     generatedBy,
	}
}

// calcArrearsAndInterest calculates unpaid arrears and interest for a flat.
func (r *BillRepository) calcArrearsAndInterest(
	flatID uuid.UUID, bs *models.BillingStructure, currentDueDate time.Time,
) (arrear float64, interest float64) {
	var bills []models.MaintenanceBill
	r.db.Where("flat_id = ? AND status IN ?", flatID,
		[]models.BillStatus{models.BillIssued, models.BillOverdue}).
		Find(&bills)

	annualRate := 0.0
	if bs != nil {
		annualRate = bs.InterestRate
	}

	for _, b := range bills {
		due := b.TotalAmount - b.AmountPaid
		if due <= 0 {
			continue
		}
		arrear += due

		// Calculate simple interest: P × R × T / (100 × 365)
		if annualRate > 0 && currentDueDate.After(b.DueDate) {
			days := currentDueDate.Sub(b.DueDate).Hours() / 24
			interest += due * annualRate * days / (100 * 365)
		}
	}
	return
}

// ListByPeriod returns all bills for a given billing period (internal use for notifications).
func (r *BillRepository) ListByPeriod(period string) ([]models.MaintenanceBill, error) {
	var rows []models.MaintenanceBill
	err := r.db.Where("billing_period = ?", period).Find(&rows).Error
	return rows, err
}

// ListForActor returns bills visible to the actor.
//   Member: only own (member_id = actor)
//   Admin:  all (optional ?flatId= filter)
func (r *BillRepository) ListForActor(actor *ActorContext, flatFilter *uuid.UUID, period string) ([]models.MaintenanceBill, error) {
	q := r.db.Model(&models.MaintenanceBill{}).Preload("Flat").Preload("Member").Preload("LineItems").
		Order("issue_date DESC")
	if !actor.IsAdmin() {
		q = q.Where("member_id = ?", actor.MemberID)
	} else if flatFilter != nil {
		q = q.Where("flat_id = ?", *flatFilter)
	}
	if period != "" {
		q = q.Where("billing_period = ?", period)
	}
	var rows []models.MaintenanceBill
	err := q.Find(&rows).Error
	return rows, err
}

// GetByID returns one bill enforcing row-level ACL.
func (r *BillRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.MaintenanceBill, error) {
	var bill models.MaintenanceBill
	if err := r.db.Preload("Flat").Preload("Member").Preload("LineItems").First(&bill, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, bill.MemberID); err != nil {
		return nil, err
	}
	return &bill, nil
}

// PendingDues returns unpaid bill total for the actor (member) or optional
// member filter for admins.
func (r *BillRepository) PendingDues(actor *ActorContext, memberFilter *uuid.UUID) (float64, int64, error) {
	q := r.db.Model(&models.MaintenanceBill{}).
		Where("status IN ?", []models.BillStatus{models.BillIssued, models.BillOverdue})
	if !actor.IsAdmin() {
		q = q.Where("member_id = ?", actor.MemberID)
	} else if memberFilter != nil {
		q = q.Where("member_id = ?", *memberFilter)
	}
	var total float64
	var count int64
	if err := q.Count(&count).Error; err != nil {
		return 0, 0, err
	}
	err := q.Select("COALESCE(SUM(total_amount - amount_paid), 0)").Row().Scan(&total)
	return total, count, err
}

// MarkPaid updates a bill as paid with an amount and optional linked txn.
func (r *BillRepository) MarkPaid(actor *ActorContext, id uuid.UUID, amount float64, txnID *uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	var bill models.MaintenanceBill
	if err := r.db.First(&bill, "id = ?", id).Error; err != nil {
		return err
	}
	newPaid := bill.AmountPaid + amount
	status := bill.Status
	var paidAt *time.Time
	if newPaid >= bill.TotalAmount {
		status = models.BillPaid
		now := time.Now()
		paidAt = &now
	}
	return r.db.Model(&bill).Updates(map[string]interface{}{
		"amount_paid":   newPaid,
		"status":        status,
		"paid_at":       paidAt,
		"linked_txn_id": txnID,
	}).Error
}

// RecordPayment creates a BillPayment record and updates the bill's AmountPaid.
// This is the primary way to record multi-mode payments (FIN-008) and partial payments (FIN-010).
func (r *BillRepository) RecordPayment(actor *ActorContext, payment *models.BillPayment) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}

	return r.db.Transaction(func(tx *gorm.DB) error {
		// Fetch bill
		var bill models.MaintenanceBill
		if err := tx.First(&bill, "id = ?", payment.BillID).Error; err != nil {
			return err
		}

		if bill.Status == models.BillPaid {
			return errors.New("bill is already fully paid")
		}

		balanceDue := bill.TotalAmount - bill.AmountPaid
		if payment.Amount > balanceDue {
			// Allow overpayment (advance) but cap bill to TotalAmount
			// Excess becomes credit balance (handled in future)
		}

		// Generate receipt number
		var count int64
		tx.Model(&models.BillPayment{}).Count(&count)
		payment.ReceiptNo = fmt.Sprintf("RCT-%d-%04d", time.Now().Year(), count+1)
		payment.RecordedByID = actor.UserID

		// Create payment record
		if err := tx.Create(payment).Error; err != nil {
			return err
		}

		// Update bill
		newPaid := bill.AmountPaid + payment.Amount
		status := bill.Status
		var paidAt *time.Time
		if newPaid >= bill.TotalAmount {
			status = models.BillPaid
			now := time.Now()
			paidAt = &now
			newPaid = bill.TotalAmount // cap at total
		}

		return tx.Model(&bill).Updates(map[string]interface{}{
			"amount_paid": newPaid,
			"status":      status,
			"paid_at":     paidAt,
		}).Error
	})
}

// ListPaymentsForBill returns all payments recorded against a bill.
func (r *BillRepository) ListPaymentsForBill(actor *ActorContext, billID uuid.UUID) ([]models.BillPayment, error) {
	// Verify actor can see this bill
	var bill models.MaintenanceBill
	if err := r.db.First(&bill, "id = ?", billID).Error; err != nil {
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, bill.MemberID); err != nil {
		return nil, err
	}

	var rows []models.BillPayment
	err := r.db.Where("bill_id = ?", billID).
		Order("payment_date ASC").
		Find(&rows).Error
	return rows, err
}

// SendPaymentReminders generates notifications for overdue bills.
// Returns count of reminders sent.
func (r *BillRepository) GetOverdueBills() ([]models.MaintenanceBill, error) {
	var bills []models.MaintenanceBill
	now := time.Now()
	err := r.db.Where("status = ? AND due_date < ?", models.BillIssued, now).
		Preload("Member").Preload("Flat").
		Find(&bills).Error
	return bills, err
}

// GetBillsDueSoon returns bills due within the next N days that are still unpaid.
func (r *BillRepository) GetBillsDueSoon(days int) ([]models.MaintenanceBill, error) {
	var bills []models.MaintenanceBill
	now := time.Now()
	deadline := now.AddDate(0, 0, days)
	err := r.db.Where("status = ? AND due_date > ? AND due_date <= ?",
		models.BillIssued, now, deadline).
		Preload("Member").Preload("Flat").
		Find(&bills).Error
	return bills, err
}

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}
