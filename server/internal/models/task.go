package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type TaskStatus string

const (
	TaskPending    TaskStatus = "PENDING"
	TaskInProgress TaskStatus = "IN_PROGRESS"
	TaskCompleted  TaskStatus = "COMPLETED"
	TaskOverdue    TaskStatus = "OVERDUE"
	TaskCancelled  TaskStatus = "CANCELLED"
)

type TaskPriority string

const (
	TaskPriorityLow    TaskPriority = "LOW"
	TaskPriorityMedium TaskPriority = "MEDIUM"
	TaskPriorityHigh   TaskPriority = "HIGH"
	TaskPriorityUrgent TaskPriority = "URGENT"
)

type TaskSource string

const (
	TaskSourceManual     TaskSource = "MANUAL"
	TaskSourceMeeting    TaskSource = "MEETING"     // auto-generated from action item
	TaskSourceGrievance  TaskSource = "GRIEVANCE"
	TaskSourceCompliance TaskSource = "COMPLIANCE"  // e.g. renew NOC
	TaskSourceBilling    TaskSource = "BILLING"     // pay maintenance
)

// Task is a pending to-do owned by a society member or admin.
// Row-level access: OwnerMemberID + AssignedByID + ADMIN.
type Task struct {
	ID          uuid.UUID    `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title       string       `gorm:"type:varchar(300);not null" json:"title"`
	TitleMr     string       `gorm:"type:varchar(300)" json:"titleMr,omitempty"`
	Description string       `gorm:"type:text" json:"description,omitempty"`
	DescriptionMr string     `gorm:"type:text" json:"descriptionMr,omitempty"`

	// Ownership — primary ACL anchor
	OwnerMemberID uuid.UUID   `gorm:"type:uuid;not null;index" json:"ownerMemberId"`
	AssignedByID  uuid.UUID   `gorm:"type:uuid;not null" json:"assignedById"`

	Priority TaskPriority `gorm:"type:varchar(10);not null;default:'MEDIUM'" json:"priority"`
	Status   TaskStatus   `gorm:"type:varchar(20);not null;default:'PENDING'" json:"status"`
	Source   TaskSource   `gorm:"type:varchar(20);not null;default:'MANUAL'" json:"source"`

	// Linked resource (polymorphic pointer)
	LinkedResourceType string     `gorm:"type:varchar(50)" json:"linkedResourceType,omitempty"` // e.g. "grievance", "meeting_action_item"
	LinkedResourceID   *uuid.UUID `gorm:"type:uuid;index" json:"linkedResourceId,omitempty"`

	DueDate     *time.Time `json:"dueDate,omitempty"`
	StartedAt   *time.Time `json:"startedAt,omitempty"`
	CompletedAt *time.Time `json:"completedAt,omitempty"`

	// Notification tracking
	ReminderSentAt *time.Time `json:"reminderSentAt,omitempty"`
	EscalatedAt    *time.Time `json:"escalatedAt,omitempty"`

	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Owner      *Member `gorm:"foreignKey:OwnerMemberID" json:"owner,omitempty"`
	AssignedBy *Member `gorm:"foreignKey:AssignedByID" json:"assignedBy,omitempty"`
}

func (t *Task) BeforeCreate(tx *gorm.DB) error {
	if t.ID == uuid.Nil {
		t.ID = uuid.New()
	}
	return nil
}

func (Task) TableName() string { return "soc_mitra_tasks" }

// IsOverdue returns whether the task is past its due date and still not completed.
func (t *Task) IsOverdue() bool {
	if t.DueDate == nil || t.Status == TaskCompleted || t.Status == TaskCancelled {
		return false
	}
	return time.Now().After(*t.DueDate)
}
