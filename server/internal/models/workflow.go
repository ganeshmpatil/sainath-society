package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ─── Workflow ────────────────────────────────────────────────────

type WorkflowStatus string

const (
	WorkflowDraft     WorkflowStatus = "DRAFT"
	WorkflowActive    WorkflowStatus = "ACTIVE"
	WorkflowCompleted WorkflowStatus = "COMPLETED"
	WorkflowCancelled WorkflowStatus = "CANCELLED"
)

type WorkflowCategory string

const (
	WFCatAGM        WorkflowCategory = "AGM"
	WFCatSGM        WorkflowCategory = "SGM"
	WFCatFestival   WorkflowCategory = "FESTIVAL"
	WFCatRepair     WorkflowCategory = "REPAIR"
	WFCatCompliance WorkflowCategory = "COMPLIANCE"
	WFCatElection   WorkflowCategory = "ELECTION"
	WFCatGeneral    WorkflowCategory = "GENERAL"
)

// Workflow is a structured plan with ordered activities.
// When IsTemplate is true it acts as a reusable blueprint.
type Workflow struct {
	ID            uuid.UUID        `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title         string           `gorm:"type:varchar(300);not null" json:"title"`
	TitleMr       string           `gorm:"type:varchar(300)" json:"titleMr,omitempty"`
	Description   string           `gorm:"type:text" json:"description,omitempty"`
	DescriptionMr string           `gorm:"type:text" json:"descriptionMr,omitempty"`
	Category      WorkflowCategory `gorm:"type:varchar(30);not null;default:'GENERAL'" json:"category"`
	Status        WorkflowStatus   `gorm:"type:varchar(20);not null;default:'DRAFT'" json:"status"`

	IsTemplate bool       `gorm:"default:false;index" json:"isTemplate"`
	TemplateID *uuid.UUID `gorm:"type:uuid;index" json:"templateId,omitempty"`

	TargetDate  *time.Time `json:"targetDate,omitempty"`
	StartedAt   *time.Time `json:"startedAt,omitempty"`
	CompletedAt *time.Time `json:"completedAt,omitempty"`

	CreatedByMemberID uuid.UUID `gorm:"type:uuid;not null" json:"createdByMemberId"`
	IsActive          bool      `gorm:"default:true" json:"isActive"`
	CreatedAt         time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt         time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	CreatedBy  *Member            `gorm:"foreignKey:CreatedByMemberID" json:"createdBy,omitempty"`
	Activities []WorkflowActivity `gorm:"foreignKey:WorkflowID;constraint:OnDelete:CASCADE" json:"activities,omitempty"`
}

func (w *Workflow) BeforeCreate(tx *gorm.DB) error {
	if w.ID == uuid.Nil {
		w.ID = uuid.New()
	}
	return nil
}
func (Workflow) TableName() string { return "soc_mitra_workflows" }

// ─── Activity ────────────────────────────────────────────────────

type ActivityStatus string

const (
	ActivityPending    ActivityStatus = "PENDING"
	ActivityInProgress ActivityStatus = "IN_PROGRESS"
	ActivityCompleted  ActivityStatus = "COMPLETED"
	ActivitySkipped    ActivityStatus = "SKIPPED"
)

// ComponentType identifies a pre-built workflow component.
type ComponentType string

const (
	CompScheduleMeeting ComponentType = "SCHEDULE_MEETING"
	CompShareMinutes    ComponentType = "SHARE_MINUTES"
	CompUploadDocument  ComponentType = "UPLOAD_DOCUMENT"
	CompIssueCheque     ComponentType = "ISSUE_CHEQUE"
	CompUploadInvoice   ComponentType = "UPLOAD_INVOICE"
	CompSendNotice      ComponentType = "SEND_NOTICE"
	CompCollectApproval ComponentType = "COLLECT_APPROVAL"
	CompCustom          ComponentType = "CUSTOM"
)

// WorkflowActivity is a single step within a workflow.
type WorkflowActivity struct {
	ID            uuid.UUID      `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	WorkflowID    uuid.UUID      `gorm:"type:uuid;not null;index" json:"workflowId"`
	Title         string         `gorm:"type:varchar(300);not null" json:"title"`
	TitleMr       string         `gorm:"type:varchar(300)" json:"titleMr,omitempty"`
	Description   string         `gorm:"type:text" json:"description,omitempty"`
	DescriptionMr string         `gorm:"type:text" json:"descriptionMr,omitempty"`
	Position      int            `gorm:"not null;default:0" json:"position"`
	Status        ActivityStatus `gorm:"type:varchar(20);not null;default:'PENDING'" json:"status"`

	ComponentType   ComponentType `gorm:"type:varchar(30);not null;default:'CUSTOM'" json:"componentType"`
	ComponentConfig string        `gorm:"type:text" json:"componentConfig,omitempty"` // JSON config for the component

	AssignedToMemberID *uuid.UUID `gorm:"type:uuid;index" json:"assignedToMemberId,omitempty"`
	DueDate            *time.Time `json:"dueDate,omitempty"`
	CompletedAt        *time.Time `json:"completedAt,omitempty"`
	CompletedByID      *uuid.UUID `gorm:"type:uuid" json:"completedById,omitempty"`

	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	AssignedTo  *Member                      `gorm:"foreignKey:AssignedToMemberID" json:"assignedTo,omitempty"`
	CompletedBy *Member                      `gorm:"foreignKey:CompletedByID" json:"completedBy,omitempty"`
	Comments    []WorkflowActivityComment    `gorm:"foreignKey:ActivityID;constraint:OnDelete:CASCADE" json:"comments,omitempty"`
	Attachments []WorkflowActivityAttachment `gorm:"foreignKey:ActivityID;constraint:OnDelete:CASCADE" json:"attachments,omitempty"`
}

func (a *WorkflowActivity) BeforeCreate(tx *gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return nil
}
func (WorkflowActivity) TableName() string { return "soc_mitra_workflow_activities" }

// ─── Activity Comment ────────────────────────────────────────────

type WorkflowActivityComment struct {
	ID         uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	ActivityID uuid.UUID `gorm:"type:uuid;not null;index" json:"activityId"`
	MemberID   uuid.UUID `gorm:"type:uuid;not null" json:"memberId"`
	Body       string    `gorm:"type:text;not null" json:"body"`
	CreatedAt  time.Time `gorm:"autoCreateTime" json:"createdAt"`

	Member *Member `gorm:"foreignKey:MemberID" json:"member,omitempty"`
}

func (c *WorkflowActivityComment) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}
func (WorkflowActivityComment) TableName() string { return "soc_mitra_workflow_activity_comments" }

// ─── Activity Attachment ─────────────────────────────────────────

type WorkflowActivityAttachment struct {
	ID             uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	ActivityID     uuid.UUID `gorm:"type:uuid;not null;index" json:"activityId"`
	FileName       string    `gorm:"type:varchar(255);not null" json:"fileName"`
	MimeType       string    `gorm:"type:varchar(100);not null" json:"mimeType"`
	OriginalSize   int64     `json:"originalSize"`
	CompressedSize int64     `json:"compressedSize"`
	FileData       []byte    `gorm:"type:bytea;not null" json:"-"`
	UploadedByID   uuid.UUID `gorm:"type:uuid;not null" json:"uploadedById"`
	CreatedAt      time.Time `gorm:"autoCreateTime" json:"createdAt"`

	UploadedBy *Member `gorm:"foreignKey:UploadedByID" json:"uploadedBy,omitempty"`
}

func (a *WorkflowActivityAttachment) BeforeCreate(tx *gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return nil
}
func (WorkflowActivityAttachment) TableName() string {
	return "soc_mitra_workflow_activity_attachments"
}

// ─── Audit Log ───────────────────────────────────────────────────

type WorkflowAuditLog struct {
	ID          uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	WorkflowID  uuid.UUID  `gorm:"type:uuid;not null;index" json:"workflowId"`
	ActivityID  *uuid.UUID `gorm:"type:uuid;index" json:"activityId,omitempty"`
	ActorID     uuid.UUID  `gorm:"type:uuid;not null" json:"actorId"`
	Action      string     `gorm:"type:varchar(30);not null" json:"action"` // CREATED, STATUS_CHANGED, ASSIGNED, COMMENT_ADDED, ATTACHMENT_ADDED, ACTIVITY_ADDED, ACTIVITY_REMOVED, REORDERED
	OldValue    string     `gorm:"type:varchar(100)" json:"oldValue,omitempty"`
	NewValue    string     `gorm:"type:varchar(100)" json:"newValue,omitempty"`
	Description string     `gorm:"type:text" json:"description,omitempty"`
	CreatedAt   time.Time  `gorm:"autoCreateTime" json:"createdAt"`

	Actor *Member `gorm:"foreignKey:ActorID" json:"actor,omitempty"`
}

func (a *WorkflowAuditLog) BeforeCreate(tx *gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return nil
}
func (WorkflowAuditLog) TableName() string { return "soc_mitra_workflow_audit_logs" }
