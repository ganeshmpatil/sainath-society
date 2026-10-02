package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AccountType string

const (
	AccountAsset     AccountType = "ASSET"
	AccountLiability AccountType = "LIABILITY"
	AccountIncome    AccountType = "INCOME"
	AccountExpense   AccountType = "EXPENSE"
	AccountFund      AccountType = "FUND"
)

// AccountHead represents a single node in the Chart of Accounts.
// Supports a tree structure via ParentID for grouping (e.g. Assets → Bank Accounts → SBI Savings).
type AccountHead struct {
	TenantScope
	ID       uuid.UUID   `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Code     string      `gorm:"type:varchar(20);uniqueIndex;not null" json:"code"`
	Name     string      `gorm:"type:varchar(150);not null" json:"name"`
	NameMr   string      `gorm:"type:varchar(150)" json:"nameMr"`
	Type     AccountType `gorm:"type:varchar(20);not null;index" json:"type"`
	ParentID *uuid.UUID  `gorm:"type:uuid;index" json:"parentId,omitempty"`
	IsGroup  bool        `gorm:"not null;default:false" json:"isGroup"`
	IsActive bool        `gorm:"not null;default:true" json:"isActive"`

	// System accounts cannot be deleted/deactivated by admin
	IsSystem bool `gorm:"not null;default:false" json:"isSystem"`

	CreatedByID *uuid.UUID `gorm:"type:uuid" json:"createdById,omitempty"`
	CreatedAt   time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relationships
	Parent   *AccountHead  `gorm:"foreignKey:ParentID" json:"parent,omitempty"`
	Children []AccountHead `gorm:"foreignKey:ParentID" json:"children,omitempty"`
}

func (a *AccountHead) BeforeCreate(tx *gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return nil
}

func (AccountHead) TableName() string { return "soc_mitra_account_heads" }
