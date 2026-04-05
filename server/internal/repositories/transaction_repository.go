package repositories

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type TransactionRepository struct {
	db *gorm.DB
}

func NewTransactionRepository(db *gorm.DB) *TransactionRepository {
	return &TransactionRepository{db: db}
}

// Create a financial transaction.
//   - Member: may create only PENDING self-payments (member_id forced to actor)
//   - Admin:  full control, can post debits, credits, society-wide expenses
func (r *TransactionRepository) Create(actor *ActorContext, t *models.FinancialTransaction) error {
	t.CreatedByID = actor.MemberID
	if !actor.IsAdmin() {
		mid := actor.MemberID
		t.MemberID = &mid
		t.Direction = models.TxnCredit
		t.PaymentStatus = models.PaymentStatusPending
	}
	if t.ReceiptNo == "" && t.Direction == models.TxnCredit {
		t.ReceiptNo = fmt.Sprintf("RCP-%d", time.Now().UnixNano()/1e6)
	}
	return r.db.Create(t).Error
}

// ListForActor — members see only their own transactions; admins see all.
func (r *TransactionRepository) ListForActor(actor *ActorContext, from, to *time.Time) ([]models.FinancialTransaction, error) {
	q := r.db.Model(&models.FinancialTransaction{}).Preload("Member").Preload("Flat").
		Order("created_at DESC")
	if !actor.IsAdmin() {
		q = q.Where("member_id = ?", actor.MemberID)
	}
	if from != nil {
		q = q.Where("created_at >= ?", *from)
	}
	if to != nil {
		q = q.Where("created_at <= ?", *to)
	}
	var rows []models.FinancialTransaction
	err := q.Find(&rows).Error
	return rows, err
}

func (r *TransactionRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.FinancialTransaction, error) {
	var t models.FinancialTransaction
	if err := r.db.Preload("Member").Preload("Flat").First(&t, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if !actor.IsAdmin() {
		if t.MemberID == nil || *t.MemberID != actor.MemberID {
			return nil, ErrForbidden
		}
	}
	return &t, nil
}

// MarkPaid updates a transaction to COMPLETED — admin only (reconciliation).
func (r *TransactionRepository) MarkPaid(actor *ActorContext, id uuid.UUID, method models.PaymentMethod, ref string) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	now := time.Now()
	return r.db.Model(&models.FinancialTransaction{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"payment_status":  models.PaymentStatusCompleted,
			"payment_method":  method,
			"transaction_ref": ref,
			"paid_at":         now,
		}).Error
}

// Summary returns credit/debit totals for the actor in a date range.
func (r *TransactionRepository) Summary(actor *ActorContext, from, to time.Time) (credit, debit float64, err error) {
	base := r.db.Model(&models.FinancialTransaction{}).
		Where("created_at BETWEEN ? AND ?", from, to).
		Where("payment_status = ?", models.PaymentStatusCompleted)
	if !actor.IsAdmin() {
		base = base.Where("member_id = ?", actor.MemberID)
	}
	err = base.Where("direction = ?", models.TxnCredit).
		Select("COALESCE(SUM(amount),0)").Row().Scan(&credit)
	if err != nil {
		return
	}
	err = base.Where("direction = ?", models.TxnDebit).
		Select("COALESCE(SUM(amount),0)").Row().Scan(&debit)
	return
}
