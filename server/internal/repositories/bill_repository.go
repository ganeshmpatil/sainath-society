package repositories

import (
	"errors"
	"fmt"
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
	BillingPeriod     string    // "2026-04"
	DueDate           time.Time
	MaintenanceCharge float64   // flat rate per flat
	SinkingFund       float64
	RepairFund        float64
	WaterCharge       float64
	OtherCharges      float64
}

// GenerateForPeriod creates a bill for every flat that does not already have
// one for the given billing period. Admin-only.
// Returns (billsCreated, skipped, error).
func (r *BillRepository) GenerateForPeriod(actor *ActorContext, req BillGenerationRequest) (int, int, error) {
	if !actor.IsAdmin() {
		return 0, 0, ErrForbidden
	}

	// Pull all (member, flat) pairs from the current seed/registry.
	type pair struct {
		MemberID uuid.UUID
		FlatID   uuid.UUID
	}
	var pairs []pair
	if err := r.db.Model(&models.Member{}).
		Where("flat_id IS NOT NULL AND is_active = ?", true).
		Select("id AS member_id, flat_id").
		Scan(&pairs).Error; err != nil {
		return 0, 0, err
	}

	total := req.MaintenanceCharge + req.SinkingFund + req.RepairFund +
		req.WaterCharge + req.OtherCharges
	issueDate := time.Now()
	created, skipped := 0, 0

	for _, p := range pairs {
		// Skip if bill already exists for this flat+period (unique index safety)
		var exists int64
		r.db.Model(&models.MaintenanceBill{}).
			Where("flat_id = ? AND billing_period = ?", p.FlatID, req.BillingPeriod).
			Count(&exists)
		if exists > 0 {
			skipped++
			continue
		}
		bill := &models.MaintenanceBill{
			BillNo:            fmt.Sprintf("BILL-%s-%d", req.BillingPeriod, time.Now().UnixNano()%1000000),
			FlatID:            p.FlatID,
			MemberID:          p.MemberID,
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
			GeneratedByID:     actor.MemberID,
		}
		if err := r.db.Create(bill).Error; err != nil {
			return created, skipped, err
		}
		created++
	}
	return created, skipped, nil
}

// ListForActor returns bills visible to the actor.
//   Member: only own (member_id = actor)
//   Admin:  all (optional ?flatId= filter)
func (r *BillRepository) ListForActor(actor *ActorContext, flatFilter *uuid.UUID, period string) ([]models.MaintenanceBill, error) {
	q := r.db.Model(&models.MaintenanceBill{}).Preload("Flat").Preload("Member").
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
	if err := r.db.Preload("Flat").Preload("Member").First(&bill, "id = ?", id).Error; err != nil {
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
