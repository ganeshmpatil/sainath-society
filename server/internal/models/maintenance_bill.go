package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type BillStatus string

const (
	BillDraft    BillStatus = "DRAFT"
	BillIssued   BillStatus = "ISSUED"
	BillPaid     BillStatus = "PAID"
	BillOverdue  BillStatus = "OVERDUE"
	BillWaived   BillStatus = "WAIVED"
)

// MaintenanceBill is a monthly/quarterly bill raised per flat.
// Unique on (flat_id, billing_period) so duplicate generation is impossible.
type MaintenanceBill struct {
	ID          uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	BillNo      string    `gorm:"type:varchar(30);uniqueIndex;not null" json:"billNo"`

	FlatID      uuid.UUID `gorm:"type:uuid;not null;index;uniqueIndex:uq_flat_period" json:"flatId"`
	MemberID    uuid.UUID `gorm:"type:uuid;not null;index" json:"memberId"`

	BillingPeriod string `gorm:"type:varchar(7);not null;uniqueIndex:uq_flat_period" json:"billingPeriod"` // e.g. "2026-04"
	IssueDate     time.Time  `gorm:"not null" json:"issueDate"`
	DueDate       time.Time  `gorm:"not null" json:"dueDate"`

	// Breakdown
	MaintenanceCharge float64 `gorm:"type:decimal(10,2);not null" json:"maintenanceCharge"`
	SinkingFund       float64 `gorm:"type:decimal(10,2);default:0" json:"sinkingFund"`
	RepairFund        float64 `gorm:"type:decimal(10,2);default:0" json:"repairFund"`
	WaterCharge       float64 `gorm:"type:decimal(10,2);default:0" json:"waterCharge"`
	OtherCharges      float64 `gorm:"type:decimal(10,2);default:0" json:"otherCharges"`
	PenaltyAmount     float64 `gorm:"type:decimal(10,2);default:0" json:"penaltyAmount"`
	TotalAmount       float64 `gorm:"type:decimal(12,2);not null" json:"totalAmount"`

	AmountPaid   float64    `gorm:"type:decimal(12,2);default:0" json:"amountPaid"`
	Status       BillStatus `gorm:"type:varchar(20);not null;default:'DRAFT'" json:"status"`
	PaidAt       *time.Time `json:"paidAt,omitempty"`

	LinkedTxnID *uuid.UUID `gorm:"type:uuid" json:"linkedTxnId,omitempty"`

	GeneratedByID uuid.UUID `gorm:"type:uuid;not null" json:"generatedById"`
	CreatedAt     time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt     time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Flat   *Flat   `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
	Member *Member `gorm:"foreignKey:MemberID" json:"member,omitempty"`
}

func (b *MaintenanceBill) BeforeCreate(tx *gorm.DB) error {
	if b.ID == uuid.Nil {
		b.ID = uuid.New()
	}
	return nil
}

func (MaintenanceBill) TableName() string { return "soc_mitra_maintenance_bills" }
