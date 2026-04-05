package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type TransactionType string

const (
	TxnMaintenance  TransactionType = "MAINTENANCE"
	TxnCorpusFund   TransactionType = "CORPUS_FUND"
	TxnSinkingFund  TransactionType = "SINKING_FUND"
	TxnPenalty      TransactionType = "PENALTY"
	TxnRepair       TransactionType = "REPAIR"
	TxnUtility      TransactionType = "UTILITY"
	TxnEvent        TransactionType = "EVENT"
	TxnSecurity     TransactionType = "SECURITY"
	TxnSalary       TransactionType = "SALARY"
	TxnMisc         TransactionType = "MISC"
)

type TransactionDirection string

const (
	TxnCredit TransactionDirection = "CREDIT" // money coming in
	TxnDebit  TransactionDirection = "DEBIT"  // money going out
)

type PaymentMethod string

const (
	PaymentCash     PaymentMethod = "CASH"
	PaymentUPI      PaymentMethod = "UPI"
	PaymentNEFT     PaymentMethod = "NEFT"
	PaymentCheque   PaymentMethod = "CHEQUE"
	PaymentCard     PaymentMethod = "CARD"
	PaymentOnline   PaymentMethod = "ONLINE"
)

type PaymentStatus string

const (
	PaymentStatusPending   PaymentStatus = "PENDING"
	PaymentStatusCompleted PaymentStatus = "COMPLETED"
	PaymentStatusFailed    PaymentStatus = "FAILED"
	PaymentStatusRefunded  PaymentStatus = "REFUNDED"
)

// FinancialTransaction records a single money movement.
// Row-level access: MemberID == actor (own transactions) + ADMIN (all).
type FinancialTransaction struct {
	ID         uuid.UUID            `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	ReceiptNo  string               `gorm:"type:varchar(30);uniqueIndex" json:"receiptNo,omitempty"`

	// Linkage (nullable for society-wide debits e.g. salary)
	MemberID   *uuid.UUID           `gorm:"type:uuid;index" json:"memberId,omitempty"`
	FlatID     *uuid.UUID           `gorm:"type:uuid;index" json:"flatId,omitempty"`

	TxnType    TransactionType      `gorm:"type:varchar(30);not null" json:"txnType"`
	Direction  TransactionDirection `gorm:"type:varchar(10);not null" json:"direction"`
	Amount     float64              `gorm:"type:decimal(12,2);not null" json:"amount"`
	Currency   string               `gorm:"type:varchar(3);default:'INR'" json:"currency"`

	// Billing period (for recurring charges)
	PeriodFrom *time.Time `json:"periodFrom,omitempty"`
	PeriodTo   *time.Time `json:"periodTo,omitempty"`
	DueDate    *time.Time `json:"dueDate,omitempty"`

	// Payment details
	PaymentMethod PaymentMethod `gorm:"type:varchar(20)" json:"paymentMethod,omitempty"`
	PaymentStatus PaymentStatus `gorm:"type:varchar(20);not null;default:'PENDING'" json:"paymentStatus"`
	PaidAt        *time.Time    `json:"paidAt,omitempty"`
	TransactionRef string       `gorm:"type:varchar(100)" json:"transactionRef,omitempty"` // UPI/NEFT ref

	Description   string `gorm:"type:varchar(500)" json:"description,omitempty"`
	DescriptionMr string `gorm:"type:varchar(500)" json:"descriptionMr,omitempty"`
	AttachmentURL string `gorm:"type:varchar(500)" json:"attachmentUrl,omitempty"` // receipt/invoice

	// Audit
	CreatedByID uuid.UUID `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Member *Member `gorm:"foreignKey:MemberID" json:"member,omitempty"`
	Flat   *Flat   `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
}

func (t *FinancialTransaction) BeforeCreate(tx *gorm.DB) error {
	if t.ID == uuid.Nil {
		t.ID = uuid.New()
	}
	return nil
}

func (FinancialTransaction) TableName() string { return "soc_mitra_financial_transactions" }
