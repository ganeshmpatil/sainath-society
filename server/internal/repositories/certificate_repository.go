package repositories

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type CertificateRepository struct {
	db *gorm.DB
}

func NewCertificateRepository(db *gorm.DB) *CertificateRepository {
	return &CertificateRepository{db: db}
}

// Request creates a new certificate request (member or admin).
func (r *CertificateRepository) Request(actor *ActorContext, cert *models.Certificate) error {
	cert.RequestedByID = actor.MemberID
	cert.Status = models.CertRequested

	// Calculate pending dues for the flat
	var pendingAmount float64
	r.db.Model(&models.MaintenanceBill{}).
		Select("COALESCE(SUM(total_amount - amount_paid), 0)").
		Where("flat_id = ? AND status IN ?", cert.FlatID,
			[]models.BillStatus{models.BillIssued, models.BillOverdue}).
		Row().Scan(&pendingAmount)
	cert.PendingAmount = pendingAmount

	// Generate certificate number
	var count int64
	r.db.Model(&models.Certificate{}).Count(&count)
	prefix := "NDC"
	if cert.Type == models.CertNOC {
		prefix = "NOC"
	}
	cert.CertNo = fmt.Sprintf("%s-%d-%04d", prefix, time.Now().Year(), count+1)

	// Auto-approve No Dues if no pending amount
	if cert.Type == models.CertNoDues && pendingAmount == 0 {
		cert.Status = models.CertApproved
		now := time.Now()
		cert.IssueDate = &now
		validUntil := now.AddDate(0, 3, 0) // valid for 3 months
		cert.ValidUntil = &validUntil
		cert.ApprovedByID = &actor.MemberID
	}

	return r.db.Create(cert).Error
}

// List returns certificates visible to the actor.
func (r *CertificateRepository) List(actor *ActorContext) ([]models.Certificate, error) {
	q := r.db.Preload("Flat").Preload("Member").Order("created_at DESC")
	if !actor.IsAdmin() {
		q = q.Where("member_id = ?", actor.MemberID)
	}
	var rows []models.Certificate
	return rows, q.Find(&rows).Error
}

// GetByID returns a certificate with ACL check.
func (r *CertificateRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Certificate, error) {
	var cert models.Certificate
	if err := r.db.Preload("Flat").Preload("Member").First(&cert, "id = ?", id).Error; err != nil {
		return nil, ErrNotFound
	}
	if err := AssertOwnerOrAdmin(actor, cert.MemberID); err != nil {
		return nil, err
	}
	return &cert, nil
}

// Approve marks a certificate as approved.
func (r *CertificateRepository) Approve(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}

	var cert models.Certificate
	if err := r.db.First(&cert, "id = ?", id).Error; err != nil {
		return ErrNotFound
	}

	// Check pending dues for No Dues certificate
	if cert.Type == models.CertNoDues {
		var pending float64
		r.db.Model(&models.MaintenanceBill{}).
			Select("COALESCE(SUM(total_amount - amount_paid), 0)").
			Where("flat_id = ? AND status IN ?", cert.FlatID,
				[]models.BillStatus{models.BillIssued, models.BillOverdue}).
			Row().Scan(&pending)
		if pending > 0 {
			return fmt.Errorf("cannot approve: flat has pending dues of ₹%.0f", pending)
		}
	}

	now := time.Now()
	validUntil := now.AddDate(0, 3, 0)
	return r.db.Model(&cert).Updates(map[string]interface{}{
		"status":        models.CertApproved,
		"issue_date":    now,
		"valid_until":   validUntil,
		"approved_by_id": actor.MemberID,
	}).Error
}

// Reject marks a certificate as rejected.
func (r *CertificateRepository) Reject(actor *ActorContext, id uuid.UUID, reason string) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.Certificate{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"status":         models.CertRejected,
			"rejection_note": reason,
			"approved_by_id": actor.MemberID,
		})
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// GetNoDuesData returns the data needed to render a No Dues certificate.
func (r *CertificateRepository) GetNoDuesData(actor *ActorContext, flatID uuid.UUID) (map[string]interface{}, error) {
	// Get member + flat info
	var member models.Member
	if err := r.db.Preload("Flat").Where("flat_id = ? AND is_active = ?", flatID, true).First(&member).Error; err != nil {
		return nil, err
	}

	// Calculate total billed, total paid, pending
	type billSummary struct {
		TotalBilled float64
		TotalPaid   float64
		Pending     float64
		BillCount   int64
	}
	var summary billSummary
	r.db.Model(&models.MaintenanceBill{}).
		Select("COALESCE(SUM(total_amount),0) as total_billed, COALESCE(SUM(amount_paid),0) as total_paid, COALESCE(SUM(total_amount - amount_paid),0) as pending, COUNT(*) as bill_count").
		Where("flat_id = ?", flatID).Scan(&summary)

	// Pending amount only for unpaid bills
	var pendingAmount float64
	r.db.Model(&models.MaintenanceBill{}).
		Select("COALESCE(SUM(total_amount - amount_paid), 0)").
		Where("flat_id = ? AND status IN ?", flatID,
			[]models.BillStatus{models.BillIssued, models.BillOverdue}).
		Row().Scan(&pendingAmount)

	return map[string]interface{}{
		"memberName":    member.Name,
		"flatNumber":    member.Flat.FlatNumber,
		"totalBilled":   summary.TotalBilled,
		"totalPaid":     summary.TotalPaid,
		"pendingAmount": pendingAmount,
		"hasDues":       pendingAmount > 0,
		"billCount":     summary.BillCount,
	}, nil
}
