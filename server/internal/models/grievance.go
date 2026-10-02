package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type GrievanceStatus string

const (
	GrievanceOpen       GrievanceStatus = "OPEN"
	GrievanceInProgress GrievanceStatus = "IN_PROGRESS"
	GrievanceResolved   GrievanceStatus = "RESOLVED"
	GrievanceRejected   GrievanceStatus = "REJECTED"
	GrievanceClosed     GrievanceStatus = "CLOSED"
)

type GrievancePriority string

const (
	PriorityLow    GrievancePriority = "LOW"
	PriorityMedium GrievancePriority = "MEDIUM"
	PriorityHigh   GrievancePriority = "HIGH"
	PriorityUrgent GrievancePriority = "URGENT"
)

type GrievanceCategory string

const (
	CategoryMaintenance GrievanceCategory = "MAINTENANCE"
	CategorySecurity    GrievanceCategory = "SECURITY"
	CategoryNoise       GrievanceCategory = "NOISE"
	CategoryParking     GrievanceCategory = "PARKING"
	CategoryCleanliness GrievanceCategory = "CLEANLINESS"
	CategoryWater       GrievanceCategory = "WATER"
	CategoryElectricity GrievanceCategory = "ELECTRICITY"
	CategoryPlumbing    GrievanceCategory = "PLUMBING"
	CategoryElectrical  GrievanceCategory = "ELECTRICAL"
	CategoryGeneral     GrievanceCategory = "GENERAL"
	CategoryOther       GrievanceCategory = "OTHER"
)

// GrievanceType distinguishes complaints from maintenance requests.
type GrievanceType string

const (
	GrievanceTypeComplaint          GrievanceType = "COMPLAINT"
	GrievanceTypeMaintenanceRequest GrievanceType = "MAINTENANCE_REQUEST"
)

// Grievance represents a complaint/request raised by a member.
// Row-level access: owner (RaisedByMemberID) + ADMIN role.
type Grievance struct {
	TenantScope
	ID          uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	TicketNo    string    `gorm:"type:varchar(20);uniqueIndex;not null" json:"ticketNo"`
	Title       string    `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr     string    `gorm:"type:varchar(200)" json:"titleMr,omitempty"`
	Description string    `gorm:"type:text;not null" json:"description"`
	DescriptionMr string  `gorm:"type:text" json:"descriptionMr,omitempty"`

	Category GrievanceCategory `gorm:"type:varchar(30);not null" json:"category"`
	Priority GrievancePriority `gorm:"type:varchar(10);not null;default:'MEDIUM'" json:"priority"`
	Status   GrievanceStatus   `gorm:"type:varchar(20);not null;default:'OPEN'" json:"status"`
	Type     GrievanceType     `gorm:"type:varchar(30);not null;default:'COMPLAINT'" json:"type"`
	FlatNo   string            `gorm:"type:varchar(20)" json:"flatNo,omitempty"`

	// Ownership fields — used for ACL
	RaisedByMemberID uuid.UUID  `gorm:"type:uuid;not null;index" json:"raisedByMemberId"`
	FlatID           *uuid.UUID `gorm:"type:uuid;index" json:"flatId,omitempty"`

	// Assignment
	AssignedToMemberID *uuid.UUID `gorm:"type:uuid;index" json:"assignedToMemberId,omitempty"`
	AssignedAt         *time.Time `json:"assignedAt,omitempty"`

	// Resolution
	Resolution     string     `gorm:"type:text" json:"resolution,omitempty"`
	ResolvedByID   *uuid.UUID `gorm:"type:uuid" json:"resolvedById,omitempty"`
	ResolvedAt     *time.Time `json:"resolvedAt,omitempty"`
	ClosedAt       *time.Time `json:"closedAt,omitempty"`

	// Attachments
	AttachmentURLs string `gorm:"type:text" json:"attachmentUrls,omitempty"` // CSV of URLs

	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	RaisedBy   *Member             `gorm:"foreignKey:RaisedByMemberID" json:"raisedBy,omitempty"`
	AssignedTo *Member             `gorm:"foreignKey:AssignedToMemberID" json:"assignedTo,omitempty"`
	Flat       *Flat               `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
	Comments   []GrievanceComment  `gorm:"foreignKey:GrievanceID" json:"comments,omitempty"`
}

func (g *Grievance) BeforeCreate(tx *gorm.DB) error {
	if g.ID == uuid.Nil {
		g.ID = uuid.New()
	}
	return nil
}

func (Grievance) TableName() string { return "soc_mitra_grievances" }

// GrievanceComment holds audit trail and back-and-forth messages
type GrievanceComment struct {
	TenantScope
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	GrievanceID  uuid.UUID `gorm:"type:uuid;not null;index" json:"grievanceId"`
	AuthorID     uuid.UUID `gorm:"type:uuid;not null" json:"authorId"`
	AuthorName   string    `gorm:"type:varchar(100)" json:"authorName,omitempty"`
	AuthorRole   string    `gorm:"type:varchar(10)" json:"authorRole,omitempty"` // MEMBER or ADMIN
	Comment      string    `gorm:"type:text;not null" json:"comment"`
	IsInternal   bool      `gorm:"default:false" json:"isInternal"` // internal admin notes
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (c *GrievanceComment) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}

func (GrievanceComment) TableName() string { return "soc_mitra_grievance_comments" }
