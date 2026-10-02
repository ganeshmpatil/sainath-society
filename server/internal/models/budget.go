package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// BudgetStatus represents the lifecycle state of a budget.
type BudgetStatus string

const (
	BudgetDraft           BudgetStatus = "DRAFT"
	BudgetCommitteeReview BudgetStatus = "COMMITTEE_REVIEW"
	BudgetAGMApproved     BudgetStatus = "AGM_APPROVED"
	BudgetActive          BudgetStatus = "ACTIVE"
)

// Budget represents a society financial year budget.
type Budget struct {
	TenantScope
	ID            uuid.UUID     `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	FinancialYear string        `gorm:"type:varchar(9);not null;uniqueIndex" json:"financialYear"` // e.g. "2026-2027"
	Title         string        `gorm:"type:varchar(200);not null" json:"title"`
	Status        BudgetStatus  `gorm:"type:varchar(20);not null;default:'DRAFT'" json:"status"`
	TotalIncome   float64       `gorm:"type:decimal(12,2);default:0" json:"totalIncome"`
	TotalExpense  float64       `gorm:"type:decimal(12,2);default:0" json:"totalExpense"`
	Surplus       float64       `gorm:"type:decimal(12,2);default:0" json:"surplus"`
	Notes         string        `gorm:"type:text" json:"notes,omitempty"`
	CreatedByID   uuid.UUID     `gorm:"type:uuid;not null" json:"createdById"`
	ApprovedByID  *uuid.UUID    `gorm:"type:uuid" json:"approvedById,omitempty"`
	ApprovedAt    *time.Time    `json:"approvedAt,omitempty"`
	CreatedAt     time.Time     `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt     time.Time     `gorm:"autoUpdateTime" json:"updatedAt"`

	LineItems []BudgetLineItem `gorm:"foreignKey:BudgetID" json:"lineItems,omitempty"`
}

func (b *Budget) BeforeCreate(tx *gorm.DB) error {
	if b.ID == uuid.Nil {
		b.ID = uuid.New()
	}
	return nil
}

func (Budget) TableName() string { return "soc_mitra_budgets" }

// BudgetLineItem represents a single income or expense head within a budget.
type BudgetLineItem struct {
	TenantScope
	ID             uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	BudgetID       uuid.UUID `gorm:"type:uuid;not null;index" json:"budgetId"`
	Category       string    `gorm:"type:varchar(10);not null" json:"category"` // INCOME or EXPENSE
	HeadName       string    `gorm:"type:varchar(100);not null" json:"headName"`
	HeadNameMr     string    `gorm:"type:varchar(100)" json:"headNameMr,omitempty"`
	BudgetedAmount float64   `gorm:"type:decimal(12,2);not null" json:"budgetedAmount"`
	ActualAmount   float64   `gorm:"type:decimal(12,2);default:0" json:"actualAmount"`
	Variance       float64   `gorm:"type:decimal(12,2);default:0" json:"variance"`
	SortOrder      int       `gorm:"default:0" json:"sortOrder"`
	Notes          string    `gorm:"type:text" json:"notes,omitempty"`
	CreatedAt      time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (li *BudgetLineItem) BeforeCreate(tx *gorm.DB) error {
	if li.ID == uuid.Nil {
		li.ID = uuid.New()
	}
	return nil
}

func (BudgetLineItem) TableName() string { return "soc_mitra_budget_line_items" }
