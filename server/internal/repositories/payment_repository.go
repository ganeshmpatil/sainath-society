package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type PaymentRepository struct {
	db *gorm.DB
}

func NewPaymentRepository(db *gorm.DB) *PaymentRepository {
	return &PaymentRepository{db: db}
}

func (r *PaymentRepository) CreateOrder(po *models.PaymentOrder) error {
	return r.db.Create(po).Error
}

func (r *PaymentRepository) GetByRazorpayOrderID(rzpOrderID string) (*models.PaymentOrder, error) {
	var po models.PaymentOrder
	if err := r.db.Where("razorpay_order_id = ?", rzpOrderID).First(&po).Error; err != nil {
		return nil, err
	}
	return &po, nil
}

func (r *PaymentRepository) UpdateOrder(po *models.PaymentOrder) error {
	return r.db.Save(po).Error
}

func (r *PaymentRepository) ListForMember(actor *ActorContext) ([]models.PaymentOrder, error) {
	q := r.db.Model(&models.PaymentOrder{}).Preload("Bill").Order("created_at DESC")
	if !actor.IsAdmin() {
		q = q.Where("member_id = ?", actor.MemberID)
	}
	var rows []models.PaymentOrder
	err := q.Find(&rows).Error
	return rows, err
}

// ─── Society Bank Config ─────────────────────────────────────────

func (r *PaymentRepository) GetBankConfig(actor *ActorContext) (*models.SocietyBankConfig, error) {
	var cfg models.SocietyBankConfig
	q := ScopeBySociety(r.db.Model(&models.SocietyBankConfig{}), actor)
	if err := q.Where("is_active = ?", true).First(&cfg).Error; err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (r *PaymentRepository) UpdateBankConfig(actor *ActorContext, cfg *models.SocietyBankConfig) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Save(cfg).Error
}

func (r *PaymentRepository) CreateBankConfig(actor *ActorContext, cfg *models.SocietyBankConfig) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	SetTenantFields(actor, &cfg.SocietyID)
	return r.db.Create(cfg).Error
}

// ─── Bill Paid by Payment Gateway ────────────────────────────────

// MarkBillPaidByPayment marks a bill as paid after a verified payment gateway
// transaction. Unlike BillRepository.MarkPaid, this does not require admin role
// because the payment has been cryptographically verified.
func (r *PaymentRepository) MarkBillPaidByPayment(billID uuid.UUID, amount float64, paymentOrderID uuid.UUID) error {
	var bill models.MaintenanceBill
	if err := r.db.First(&bill, "id = ?", billID).Error; err != nil {
		return err
	}
	newPaid := bill.AmountPaid + amount
	updates := map[string]interface{}{
		"amount_paid":   newPaid,
		"linked_txn_id": paymentOrderID,
	}
	if newPaid >= bill.TotalAmount {
		updates["status"] = models.BillPaid
		now := gorm.Expr("NOW()")
		updates["paid_at"] = now
	}
	return r.db.Model(&bill).Updates(updates).Error
}
