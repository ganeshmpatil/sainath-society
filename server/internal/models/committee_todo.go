package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type TodoCategory string

const (
	TodoCategoryAGM                 TodoCategory = "AGM"
	TodoCategorySGM                 TodoCategory = "SGM"
	TodoCategoryAudit               TodoCategory = "AUDIT"
	TodoCategoryInsurance           TodoCategory = "INSURANCE"
	TodoCategoryFireSafety          TodoCategory = "FIRE_SAFETY"
	TodoCategoryTaxFiling           TodoCategory = "TAX_FILING"
	TodoCategoryMaintenanceContract TodoCategory = "MAINTENANCE_CONTRACT"
	TodoCategoryElection            TodoCategory = "ELECTION"
	TodoCategoryFestival            TodoCategory = "FESTIVAL"
	TodoCategoryCompliance          TodoCategory = "COMPLIANCE"
	TodoCategoryLegal               TodoCategory = "LEGAL"
	TodoCategoryGeneral             TodoCategory = "GENERAL"
)

type TodoStatus string

const (
	TodoPending    TodoStatus = "PENDING"
	TodoInProgress TodoStatus = "IN_PROGRESS"
	TodoCompleted  TodoStatus = "COMPLETED"
	TodoCancelled  TodoStatus = "CANCELLED"
)

type TodoPriority string

const (
	TodoPriorityLow    TodoPriority = "LOW"
	TodoPriorityMedium TodoPriority = "MEDIUM"
	TodoPriorityHigh   TodoPriority = "HIGH"
	TodoPriorityUrgent TodoPriority = "URGENT"
)

// CommitteeTodo represents a time-bound administrative or compliance task
// managed by the society committee. Visible to all, writable by admins only.
type CommitteeTodo struct {
	TenantScope
	ID            uuid.UUID    `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title         string       `gorm:"type:varchar(300);not null" json:"title"`
	TitleMr       string       `gorm:"type:varchar(300)" json:"titleMr,omitempty"`
	Description   string       `gorm:"type:text" json:"description,omitempty"`
	DescriptionMr string       `gorm:"type:text" json:"descriptionMr,omitempty"`
	Category      TodoCategory `gorm:"type:varchar(30);not null;default:'GENERAL'" json:"category"`
	Priority      TodoPriority `gorm:"type:varchar(10);not null;default:'MEDIUM'" json:"priority"`
	Status        TodoStatus   `gorm:"type:varchar(20);not null;default:'PENDING'" json:"status"`
	DueDate       time.Time    `gorm:"not null;index" json:"dueDate"`
	Notes         string       `gorm:"type:text" json:"notes,omitempty"`
	NotesMr       string       `gorm:"type:text" json:"notesMr,omitempty"`

	// Who is responsible and who created it
	AssignedToMemberID *uuid.UUID `gorm:"type:uuid;index" json:"assignedToMemberId,omitempty"`
	CreatedByMemberID  uuid.UUID  `gorm:"type:uuid;not null" json:"createdByMemberId"`

	CompletedAt *time.Time `json:"completedAt,omitempty"`
	IsActive    bool       `gorm:"default:true" json:"isActive"`
	CreatedAt   time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	AssignedTo *Member `gorm:"foreignKey:AssignedToMemberID" json:"assignedTo,omitempty"`
	CreatedBy  *Member `gorm:"foreignKey:CreatedByMemberID" json:"createdBy,omitempty"`
}

func (ct *CommitteeTodo) BeforeCreate(tx *gorm.DB) error {
	if ct.ID == uuid.Nil {
		ct.ID = uuid.New()
	}
	return nil
}

func (CommitteeTodo) TableName() string { return "soc_mitra_committee_todos" }

// IsOverdue returns true if the todo is past due and not completed/cancelled.
func (ct *CommitteeTodo) IsOverdue() bool {
	if ct.Status == TodoCompleted || ct.Status == TodoCancelled {
		return false
	}
	return time.Now().After(ct.DueDate)
}
