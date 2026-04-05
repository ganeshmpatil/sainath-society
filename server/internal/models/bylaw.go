package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ByLaw represents a single rule/clause in the society bylaws.
// Visible to all members (PUBLIC); editable only by admins.
type ByLaw struct {
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Section      string    `gorm:"type:varchar(20);not null;index" json:"section"` // e.g. "3.2.1"
	Title        string    `gorm:"type:varchar(300);not null" json:"title"`
	TitleMr      string    `gorm:"type:varchar(300)" json:"titleMr,omitempty"`
	Content      string    `gorm:"type:text;not null" json:"content"`
	ContentMr    string    `gorm:"type:text" json:"contentMr,omitempty"`
	Category     string    `gorm:"type:varchar(50)" json:"category,omitempty"`
	Version      int       `gorm:"default:1" json:"version"`
	IsActive     bool      `gorm:"default:true" json:"isActive"`
	EffectiveFrom *time.Time `json:"effectiveFrom,omitempty"`
	SupersededBy *uuid.UUID `gorm:"type:uuid" json:"supersededBy,omitempty"`

	// Audit
	CreatedByID uuid.UUID `gorm:"type:uuid;not null" json:"createdById"`
	ApprovedByID *uuid.UUID `gorm:"type:uuid" json:"approvedById,omitempty"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (b *ByLaw) BeforeCreate(tx *gorm.DB) error {
	if b.ID == uuid.Nil {
		b.ID = uuid.New()
	}
	return nil
}

func (ByLaw) TableName() string { return "soc_mitra_bylaws" }

// ByLawAmendmentLog keeps a historical trail of amendments for audit.
type ByLawAmendmentLog struct {
	ID         uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	ByLawID    uuid.UUID `gorm:"type:uuid;not null;index" json:"bylawId"`
	OldContent string    `gorm:"type:text" json:"oldContent"`
	NewContent string    `gorm:"type:text" json:"newContent"`
	ChangedByID uuid.UUID `gorm:"type:uuid;not null" json:"changedById"`
	Reason     string    `gorm:"type:varchar(500)" json:"reason,omitempty"`
	CreatedAt  time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (ByLawAmendmentLog) TableName() string { return "soc_mitra_bylaw_amendment_logs" }
