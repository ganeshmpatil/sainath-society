package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ─── Billing Cycle Type ─────────────────────────────────────────────────────

type BillingCycle string

const (
	BillingCycleMonthEnd    BillingCycle = "MONTH_END"
	BillingCycleAnniversary BillingCycle = "ANNIVERSARY"
)

// ─── Invoice Status ─────────────────────────────────────────────────────────

type InvoiceStatus string

const (
	InvoiceGenerated    InvoiceStatus = "GENERATED"
	InvoicePaid         InvoiceStatus = "PAID"
	InvoiceOverdue      InvoiceStatus = "OVERDUE"
	InvoicePartiallyPaid InvoiceStatus = "PARTIALLY_PAID"
	InvoiceWaived       InvoiceStatus = "WAIVED"
)

// ─── Platform Billing Config ────────────────────────────────────────────────

// PlatformBillingConfig holds per-society billing terms, set during approval.
type PlatformBillingConfig struct {
	ID               uuid.UUID    `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	SocietyID        uuid.UUID    `gorm:"type:uuid;uniqueIndex;not null" json:"societyId"`
	RatePerFlat      float64      `gorm:"type:decimal(10,2);not null" json:"ratePerFlat"`
	BillingCycle     BillingCycle `gorm:"type:varchar(20);default:'MONTH_END'" json:"billingCycle"`
	BillingDay       int          `gorm:"default:0" json:"billingDay"`
	DueDays          int          `gorm:"default:15" json:"dueDays"`
	GraceDays        int          `gorm:"default:5" json:"graceDays"`
	InterestRate     float64      `gorm:"type:decimal(5,2);default:18.0" json:"interestRate"`
	GSTApplicable    bool         `gorm:"default:false" json:"gstApplicable"`
	GSTNumber        string       `gorm:"type:varchar(20)" json:"gstNumber,omitempty"`
	BillPrefix       string       `gorm:"type:varchar(10);not null" json:"billPrefix"`
	NextSequence     int          `gorm:"default:1" json:"nextSequence"`
	StartBillingFrom time.Time    `gorm:"not null" json:"startBillingFrom"`
	IsActive         bool         `gorm:"default:true" json:"isActive"`
	CreatedAt        time.Time    `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt        time.Time    `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	Society *PlatformSociety `gorm:"foreignKey:SocietyID" json:"society,omitempty"`
}

func (c *PlatformBillingConfig) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}

func (PlatformBillingConfig) TableName() string { return "platform_billing_configs" }

// ─── Platform Invoice ───────────────────────────────────────────────────────

// PlatformInvoice is a monthly invoice charged to a society by the platform.
type PlatformInvoice struct {
	ID             uuid.UUID     `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	SocietyID      uuid.UUID     `gorm:"type:uuid;not null;index" json:"societyId"`
	InvoiceNo      string        `gorm:"type:varchar(50);uniqueIndex;not null" json:"invoiceNo"`
	BillingPeriod  string        `gorm:"type:varchar(20);not null" json:"billingPeriod"`
	PeriodStart    time.Time     `gorm:"not null" json:"periodStart"`
	PeriodEnd      time.Time     `gorm:"not null" json:"periodEnd"`
	TotalFlats     int           `gorm:"not null" json:"totalFlats"`
	RatePerFlat    float64       `gorm:"type:decimal(10,2);not null" json:"ratePerFlat"`
	BaseAmount     float64       `gorm:"type:decimal(12,2);not null" json:"baseAmount"`
	GSTPercent     float64       `gorm:"type:decimal(5,2);default:0" json:"gstPercent"`
	GSTAmount      float64       `gorm:"type:decimal(12,2);default:0" json:"gstAmount"`
	Arrears        float64       `gorm:"type:decimal(12,2);default:0" json:"arrears"`
	InterestAmount float64       `gorm:"type:decimal(12,2);default:0" json:"interestAmount"`
	TotalAmount    float64       `gorm:"type:decimal(12,2);not null" json:"totalAmount"`
	DueDate        time.Time     `gorm:"not null" json:"dueDate"`
	Status         InvoiceStatus `gorm:"type:varchar(20);default:'GENERATED';index" json:"status"`
	PaidAmount     float64       `gorm:"type:decimal(12,2);default:0" json:"paidAmount"`
	PaidDate       *time.Time    `json:"paidDate,omitempty"`
	PaymentRef     string        `gorm:"type:varchar(100)" json:"paymentRef,omitempty"`
	PaymentMode    string        `gorm:"type:varchar(20)" json:"paymentMode,omitempty"`
	Notes          string        `gorm:"type:text" json:"notes,omitempty"`
	CreatedAt      time.Time     `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt      time.Time     `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	Society *PlatformSociety `gorm:"foreignKey:SocietyID" json:"society,omitempty"`
}

func (i *PlatformInvoice) BeforeCreate(tx *gorm.DB) error {
	if i.ID == uuid.Nil {
		i.ID = uuid.New()
	}
	return nil
}

func (PlatformInvoice) TableName() string { return "platform_invoices" }

// ─── Platform Billing Audit ─────────────────────────────────────────────────

// PlatformBillingAudit records each billing run for accountability.
type PlatformBillingAudit struct {
	ID              uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	RunDate         time.Time `gorm:"not null" json:"runDate"`
	RunType         string    `gorm:"type:varchar(20);not null" json:"runType"`
	SocietiesBilled int       `gorm:"default:0" json:"societiesBilled"`
	TotalAmount     float64   `gorm:"type:decimal(12,2);default:0" json:"totalAmount"`
	Status          string    `gorm:"type:varchar(20);not null" json:"status"`
	Details         string    `gorm:"type:text" json:"details,omitempty"`
	CreatedAt       time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (a *PlatformBillingAudit) BeforeCreate(tx *gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return nil
}

func (PlatformBillingAudit) TableName() string { return "platform_billing_audits" }
