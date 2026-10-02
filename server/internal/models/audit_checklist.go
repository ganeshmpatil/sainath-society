package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// AuditChecklist represents an annual audit preparation checklist.
type AuditChecklist struct {
	TenantScope
	ID            uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	FinancialYear string     `gorm:"type:varchar(9);not null;uniqueIndex" json:"financialYear"`
	Title         string     `gorm:"type:varchar(200);not null" json:"title"`
	Status        string     `gorm:"type:varchar(20);not null;default:'IN_PROGRESS'" json:"status"` // IN_PROGRESS, READY, SUBMITTED
	AuditorName   string     `gorm:"type:varchar(100)" json:"auditorName,omitempty"`
	AuditDate     *time.Time `json:"auditDate,omitempty"`
	Notes         string     `gorm:"type:text" json:"notes,omitempty"`
	CreatedByID   uuid.UUID  `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt     time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt     time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`

	Items []AuditChecklistItem `gorm:"foreignKey:ChecklistID" json:"items,omitempty"`
}

func (a *AuditChecklist) BeforeCreate(tx *gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return nil
}

func (AuditChecklist) TableName() string { return "soc_mitra_audit_checklists" }

// AuditChecklistItem is a single item in the audit checklist.
type AuditChecklistItem struct {
	TenantScope
	ID          uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	ChecklistID uuid.UUID  `gorm:"type:uuid;not null;index" json:"checklistId"`
	Category    string     `gorm:"type:varchar(50);not null" json:"category"` // FINANCIAL, LEGAL, COMPLIANCE, DOCUMENTS, REGISTERS
	Title       string     `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr     string     `gorm:"type:varchar(200)" json:"titleMr,omitempty"`
	Description string     `gorm:"type:text" json:"description,omitempty"`
	IsCompleted bool       `gorm:"default:false" json:"isCompleted"`
	CompletedBy *uuid.UUID `gorm:"type:uuid" json:"completedBy,omitempty"`
	CompletedAt *time.Time `json:"completedAt,omitempty"`
	Remarks     string     `gorm:"type:text" json:"remarks,omitempty"`
	SortOrder   int        `gorm:"default:0" json:"sortOrder"`
	CreatedAt   time.Time  `gorm:"autoCreateTime" json:"createdAt"`
}

func (i *AuditChecklistItem) BeforeCreate(tx *gorm.DB) error {
	if i.ID == uuid.Nil {
		i.ID = uuid.New()
	}
	return nil
}

func (AuditChecklistItem) TableName() string { return "soc_mitra_audit_checklist_items" }
