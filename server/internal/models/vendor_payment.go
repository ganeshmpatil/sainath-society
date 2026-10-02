package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// VendorPayment records a payment to a vendor with TDS deduction.
type VendorPayment struct {
	TenantScope
	ID          uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	VendorID    uuid.UUID  `gorm:"type:uuid;not null;index" json:"vendorId"`
	PaymentDate time.Time  `gorm:"not null" json:"paymentDate"`
	GrossAmount float64    `gorm:"type:decimal(12,2);not null" json:"grossAmount"`
	TDSSection  string     `gorm:"type:varchar(10)" json:"tdsSection"`
	TDSRate     float64    `gorm:"type:decimal(5,2);default:0" json:"tdsRate"`
	TDSAmount   float64    `gorm:"type:decimal(12,2);default:0" json:"tdsAmount"`
	NetAmount   float64    `gorm:"type:decimal(12,2);not null" json:"netAmount"` // gross - TDS
	Narration   string     `gorm:"type:varchar(500)" json:"narration"`
	NarrationMr string     `gorm:"type:varchar(500)" json:"narrationMr"`
	PaymentMode string     `gorm:"type:varchar(20);default:'BANK'" json:"paymentMode"` // BANK, CASH, CHEQUE, UPI
	Reference   string     `gorm:"type:varchar(100)" json:"reference"` // cheque no, UTR, etc.

	// TDS deposit tracking
	TDSDeposited   bool       `gorm:"default:false" json:"tdsDeposited"`
	TDSChallanNo   string     `gorm:"type:varchar(50)" json:"tdsChallanNo"`
	TDSDepositDate *time.Time `json:"tdsDepositDate,omitempty"`

	// Expense account for journal entry
	ExpenseAccountID *uuid.UUID `gorm:"type:uuid" json:"expenseAccountId,omitempty"`

	// Journal entry reference
	JournalEntryID *uuid.UUID `gorm:"type:uuid" json:"journalEntryId,omitempty"`

	CreatedByID *uuid.UUID `gorm:"type:uuid" json:"createdById,omitempty"`
	CreatedAt   time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relationships
	Vendor Vendor `gorm:"foreignKey:VendorID" json:"vendor,omitempty"`
}

func (v *VendorPayment) BeforeCreate(tx *gorm.DB) error {
	if v.ID == uuid.Nil {
		v.ID = uuid.New()
	}
	return nil
}

func (VendorPayment) TableName() string { return "soc_mitra_vendor_payments" }
