package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PaymentMode string

const (
	PayModeRazorpay PaymentMode = "RAZORPAY"
	PayModeUPI      PaymentMode = "UPI"
	PayModeNEFT     PaymentMode = "NEFT"
	PayModeCheque   PaymentMode = "CHEQUE"
	PayModeCash     PaymentMode = "CASH"
)

type ChequeStatus string

const (
	ChequeReceived ChequeStatus = "RECEIVED"
	ChequeCleared  ChequeStatus = "CLEARED"
	ChequeBounced  ChequeStatus = "BOUNCED"
)

type BillPaymentStatus string

const (
	BillPaymentConfirmed BillPaymentStatus = "CONFIRMED" // admin-recorded or admin-approved
	BillPaymentPending   BillPaymentStatus = "PENDING"   // member self-reported, awaiting admin review
	BillPaymentRejected  BillPaymentStatus = "REJECTED"  // admin rejected member's claim
)

// BillPayment tracks each individual payment made against a maintenance bill.
// A bill can have multiple payments (partial payments).
type BillPayment struct {
	TenantScope
	ID     uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	BillID uuid.UUID `gorm:"type:uuid;not null;index" json:"billId"`

	Amount      float64     `gorm:"type:decimal(12,2);not null" json:"amount"`
	PaymentMode PaymentMode `gorm:"type:varchar(20);not null" json:"paymentMode"`
	PaymentDate time.Time   `gorm:"not null" json:"paymentDate"`

	// Reference details by mode
	Reference     string `gorm:"type:varchar(100)" json:"reference"`   // UTR for UPI/NEFT, cheque no, Razorpay payment ID
	ChequeBank    string `gorm:"type:varchar(100)" json:"chequeBank"`  // only for cheque
	ChequeDate    *time.Time `json:"chequeDate,omitempty"`              // only for cheque
	ChequeStatus  ChequeStatus `gorm:"type:varchar(20)" json:"chequeStatus,omitempty"`

	// Self-report workflow
	Status         BillPaymentStatus `gorm:"type:varchar(20);not null;default:'CONFIRMED'" json:"status"`
	ProofImageData []byte            `gorm:"type:bytea" json:"-"`                               // screenshot/proof stored in DB
	ProofMimeType  string            `gorm:"type:varchar(50)" json:"proofMimeType,omitempty"`
	RejectedReason string            `gorm:"type:varchar(500)" json:"rejectedReason,omitempty"`
	ConfirmedByID  *uuid.UUID        `gorm:"type:uuid" json:"confirmedById,omitempty"`
	ConfirmedAt    *time.Time        `json:"confirmedAt,omitempty"`

	ReceiptNo string `gorm:"type:varchar(30)" json:"receiptNo"` // auto-generated receipt number

	RecordedByID uuid.UUID `gorm:"type:uuid;not null" json:"recordedById"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	HasProof bool             `gorm:"-" json:"hasProof"` // computed, not stored
	Bill     *MaintenanceBill `gorm:"foreignKey:BillID" json:"bill,omitempty"`
}

func (bp *BillPayment) AfterFind(tx *gorm.DB) error {
	bp.HasProof = len(bp.ProofImageData) > 0
	return nil
}

func (bp *BillPayment) BeforeCreate(tx *gorm.DB) error {
	if bp.ID == uuid.Nil {
		bp.ID = uuid.New()
	}
	return nil
}

func (BillPayment) TableName() string { return "soc_mitra_bill_payments" }
