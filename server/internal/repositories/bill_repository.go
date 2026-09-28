package repositories

import (
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
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
			r.db.Create(&lineItems)
		}

		created++
	}
	return created, skipped, nil
}

// buildBillFromStructure calculates per-flat charges from the active billing structure.
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

	var total float64
	var items []models.BillLineItem

	area := f.AreaSqft
	if area <= 0 {
		area = 1200 // default sqft if not set
	}

	for _, ch := range bs.ChargeHeads {
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

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}
