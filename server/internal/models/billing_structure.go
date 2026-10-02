package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ─── Calculation Methods ────────────────────────────────────────

type CalcMethod string

const (
	CalcPerSqft CalcMethod = "PER_SQFT" // rate × flat.AreaSqft
	CalcFixed   CalcMethod = "FIXED"    // flat amount per flat
)

// ─── Billing Structure ──────────────────────────────────────────

// BillingStructure defines the template for monthly bill generation.
// Only one structure should be active at a time.
type BillingStructure struct {
	TenantScope
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name         string    `gorm:"type:varchar(100);not null" json:"name"`
	NameMr       string    `gorm:"type:varchar(100)" json:"nameMr,omitempty"`
	InterestRate float64   `gorm:"type:decimal(5,2);default:0" json:"interestRate"` // annual % on overdue (e.g. 18.0)
	IsActive     bool      `gorm:"default:true" json:"isActive"`
	CreatedByID  uuid.UUID `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	ChargeHeads []ChargeHead `gorm:"foreignKey:BillingStructureID" json:"chargeHeads,omitempty"`
}

func (b *BillingStructure) BeforeCreate(tx *gorm.DB) error {
	if b.ID == uuid.Nil {
		b.ID = uuid.New()
	}
	return nil
}

func (BillingStructure) TableName() string { return "soc_mitra_billing_structures" }

// ─── Charge Head ────────────────────────────────────────────────

// ChargeHead is a single line-item type within a billing structure
// (e.g., Maintenance @ ₹3/sqft, Water @ ₹200 fixed).
type ChargeHead struct {
	TenantScope
	ID                 uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	BillingStructureID uuid.UUID  `gorm:"type:uuid;not null;index" json:"billingStructureId"`
	Name               string     `gorm:"type:varchar(100);not null" json:"name"`
	NameMr             string     `gorm:"type:varchar(100)" json:"nameMr,omitempty"`
	CalcMethod         CalcMethod `gorm:"type:varchar(20);not null;default:'FIXED'" json:"calcMethod"`
	Rate               float64    `gorm:"type:decimal(10,2);not null" json:"rate"`
	SortOrder          int        `gorm:"default:0" json:"sortOrder"`
	IsActive           bool       `gorm:"default:true" json:"isActive"`
	CreatedAt          time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt          time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (ch *ChargeHead) BeforeCreate(tx *gorm.DB) error {
	if ch.ID == uuid.Nil {
		ch.ID = uuid.New()
	}
	return nil
}

func (ChargeHead) TableName() string { return "soc_mitra_charge_heads" }

// ─── Bill Line Item ─────────────────────────────────────────────

// BillLineItem stores per-charge breakdown for a generated bill.
type BillLineItem struct {
	TenantScope
	ID           uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	BillID       uuid.UUID  `gorm:"type:uuid;not null;index" json:"billId"`
	ChargeHeadID *uuid.UUID `gorm:"type:uuid" json:"chargeHeadId,omitempty"` // null for arrears/interest
	Label        string     `gorm:"type:varchar(100);not null" json:"label"`
	LabelMr      string     `gorm:"type:varchar(100)" json:"labelMr,omitempty"`
	CalcMethod   CalcMethod `gorm:"type:varchar(20)" json:"calcMethod,omitempty"`
	Rate         float64    `gorm:"type:decimal(10,2);default:0" json:"rate"`
	Quantity     float64    `gorm:"type:decimal(10,2);default:1" json:"quantity"` // sqft or 1
	Amount       float64    `gorm:"type:decimal(10,2);not null" json:"amount"`
	IsArrear     bool       `gorm:"default:false" json:"isArrear"`
	IsInterest   bool       `gorm:"default:false" json:"isInterest"`
	CreatedAt    time.Time  `gorm:"autoCreateTime" json:"createdAt"`
}

func (li *BillLineItem) BeforeCreate(tx *gorm.DB) error {
	if li.ID == uuid.Nil {
		li.ID = uuid.New()
	}
	return nil
}

func (BillLineItem) TableName() string { return "soc_mitra_bill_line_items" }
