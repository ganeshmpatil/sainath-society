package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ─── Payment Order ───────────────────────────────────────────────

type RzpPaymentStatus string

const (
	PaymentCreated  RzpPaymentStatus = "CREATED"
	PaymentPaid     RzpPaymentStatus = "PAID"
	PaymentFailed   RzpPaymentStatus = "FAILED"
	PaymentRefunded RzpPaymentStatus = "REFUNDED"
)

// PaymentOrder tracks a Razorpay order linked to a maintenance bill.
type PaymentOrder struct {
	ID uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`

	BillID   uuid.UUID `gorm:"type:uuid;not null;index" json:"billId"`
	MemberID uuid.UUID `gorm:"type:uuid;not null;index" json:"memberId"`

	// Razorpay fields
	RazorpayOrderID   string `gorm:"type:varchar(50);uniqueIndex" json:"razorpayOrderId"`
	RazorpayPaymentID string `gorm:"type:varchar(50)" json:"razorpayPaymentId,omitempty"`
	RazorpaySignature string `gorm:"type:varchar(200)" json:"-"`

	Amount   int64         `gorm:"not null" json:"amount"`         // in paise (INR * 100)
	Currency string        `gorm:"type:varchar(3);default:'INR'" json:"currency"`
	Status   RzpPaymentStatus `gorm:"type:varchar(20);not null;default:'CREATED'" json:"status"`

	PaidAt    *time.Time `json:"paidAt,omitempty"`
	CreatedAt time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`

	Bill   *MaintenanceBill `gorm:"foreignKey:BillID" json:"bill,omitempty"`
	Member *Member          `gorm:"foreignKey:MemberID" json:"member,omitempty"`
}

func (p *PaymentOrder) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (PaymentOrder) TableName() string { return "soc_mitra_payment_orders" }

// ─── Society Bank Config ─────────────────────────────────────────

// SocietyBankConfig stores society bank details (displayed on payment screens).
type SocietyBankConfig struct {
	ID            uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	AccountName   string    `gorm:"type:varchar(200);not null" json:"accountName"`
	AccountNumber string    `gorm:"type:varchar(20);not null" json:"accountNumber"`
	BankName      string    `gorm:"type:varchar(100);not null" json:"bankName"`
	BranchName    string    `gorm:"type:varchar(200)" json:"branchName"`
	IFSC          string    `gorm:"type:varchar(11);not null" json:"ifsc"`
	UpiID         string    `gorm:"type:varchar(100)" json:"upiId,omitempty"`
	IsActive      bool      `gorm:"default:true" json:"isActive"`
	CreatedAt     time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt     time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (s *SocietyBankConfig) BeforeCreate(tx *gorm.DB) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	return nil
}

func (SocietyBankConfig) TableName() string { return "soc_mitra_society_bank_config" }
