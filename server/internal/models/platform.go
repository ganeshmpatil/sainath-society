package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ─── Onboarding Request Status ──────────────────────────────────────────────

type OnboardingStatus string

const (
	OnboardingPending       OnboardingStatus = "PENDING"
	OnboardingApproved      OnboardingStatus = "APPROVED"
	OnboardingRejected      OnboardingStatus = "REJECTED"
	OnboardingInfoRequested OnboardingStatus = "INFO_REQUESTED"
)

// ─── Society Status ─────────────────────────────────────────────────────────

type SocietyStatus string

const (
	SocietyActive     SocietyStatus = "ACTIVE"
	SocietySuspended  SocietyStatus = "SUSPENDED"
	SocietyOnboarding SocietyStatus = "ONBOARDING"
)

// ─── Platform Admin ─────────────────────────────────────────────────────────

// PlatformAdmin represents a platform-level administrator (you, not society admins).
// Separate from society users — these are the people who approve/reject societies.
type PlatformAdmin struct {
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name         string    `gorm:"type:varchar(100);not null" json:"name"`
	Email        string    `gorm:"type:varchar(255);uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"type:varchar(255);not null" json:"-"`
	IsActive     bool      `gorm:"default:true" json:"isActive"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (p *PlatformAdmin) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (PlatformAdmin) TableName() string { return "platform_admins" }

// ─── Platform Society ───────────────────────────────────────────────────────

// PlatformSociety is the master registry of all societies on the platform.
// Each approved society gets a row here. The ID is used as the tenant key
// (society_id) across all soc_mitra_* tables.
type PlatformSociety struct {
	ID                 uuid.UUID     `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name               string        `gorm:"type:varchar(200);not null" json:"name"`
	NameMr             string        `gorm:"type:varchar(200)" json:"nameMr,omitempty"`
	RegistrationNumber string        `gorm:"type:varchar(100);uniqueIndex;not null" json:"registrationNumber"`
	Slug               string        `gorm:"type:varchar(100);uniqueIndex;not null" json:"slug"`
	Address            string        `gorm:"type:text" json:"address,omitempty"`
	City               string        `gorm:"type:varchar(100)" json:"city,omitempty"`
	PinCode            string        `gorm:"type:varchar(6)" json:"pinCode,omitempty"`
	State              string        `gorm:"type:varchar(50);default:'Maharashtra'" json:"state"`
	TotalWings         int           `gorm:"default:0" json:"totalWings"`
	TotalFlats         int           `gorm:"default:0" json:"totalFlats"`
	Status             SocietyStatus `gorm:"type:varchar(20);default:'ONBOARDING'" json:"status"`

	// Primary contact (the secretary/chairman who requested onboarding)
	AdminName  string `gorm:"type:varchar(100)" json:"adminName,omitempty"`
	AdminEmail string `gorm:"type:varchar(255)" json:"adminEmail,omitempty"`
	AdminPhone string `gorm:"type:varchar(15)" json:"adminPhone,omitempty"`

	// Audit
	ApprovedByID *uuid.UUID `gorm:"type:uuid" json:"approvedById,omitempty"`
	ApprovedAt   *time.Time `json:"approvedAt,omitempty"`
	SuspendedAt  *time.Time `json:"suspendedAt,omitempty"`
	SuspendReason string    `gorm:"type:text" json:"suspendReason,omitempty"`
	CreatedAt    time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	ApprovedBy *PlatformAdmin `gorm:"foreignKey:ApprovedByID" json:"approvedBy,omitempty"`
}

func (s *PlatformSociety) BeforeCreate(tx *gorm.DB) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	return nil
}

func (PlatformSociety) TableName() string { return "platform_societies" }

// ─── Onboarding Request ─────────────────────────────────────────────────────

// PlatformOnboardingRequest captures a society's application to join the platform.
// A platform admin reviews this and either approves (→ provisions society) or rejects.
type PlatformOnboardingRequest struct {
	ID                 uuid.UUID        `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	RequestNo          string           `gorm:"type:varchar(30);uniqueIndex;not null" json:"requestNo"`
	SocietyName        string           `gorm:"type:varchar(200);not null" json:"societyName"`
	SocietyNameMr      string           `gorm:"type:varchar(200)" json:"societyNameMr,omitempty"`
	RegistrationNumber string           `gorm:"type:varchar(100);not null" json:"registrationNumber"`
	Address            string           `gorm:"type:text" json:"address,omitempty"`
	City               string           `gorm:"type:varchar(100)" json:"city,omitempty"`
	PinCode            string           `gorm:"type:varchar(6)" json:"pinCode,omitempty"`
	TotalWings         int              `gorm:"default:0" json:"totalWings"`
	TotalFlats         int              `gorm:"default:0" json:"totalFlats"`

	// Requester details (the person submitting the application)
	RequesterName        string `gorm:"type:varchar(100);not null" json:"requesterName"`
	RequesterPhone       string `gorm:"type:varchar(15);not null" json:"requesterPhone"`
	RequesterEmail       string `gorm:"type:varchar(255);not null" json:"requesterEmail"`
	RequesterDesignation string `gorm:"type:varchar(50)" json:"requesterDesignation,omitempty"`

	// Uploaded proof documents (URLs to object storage)
	CertificateURL string `gorm:"type:text" json:"certificateUrl,omitempty"`
	LetterheadURL  string `gorm:"type:text" json:"letterheadUrl,omitempty"`

	// Review workflow
	Status        OnboardingStatus `gorm:"type:varchar(20);default:'PENDING';index" json:"status"`
	ReviewerNotes string           `gorm:"type:text" json:"reviewerNotes,omitempty"`
	RejectReason  string           `gorm:"type:text" json:"rejectReason,omitempty"`
	InfoRequest   string           `gorm:"type:text" json:"infoRequest,omitempty"`

	// Links
	ReviewedByID     *uuid.UUID `gorm:"type:uuid" json:"reviewedById,omitempty"`
	ReviewedAt       *time.Time `json:"reviewedAt,omitempty"`
	ProvisionedSocID *uuid.UUID `gorm:"type:uuid" json:"provisionedSocietyId,omitempty"`

	// Audit
	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	ReviewedBy *PlatformAdmin  `gorm:"foreignKey:ReviewedByID" json:"reviewedBy,omitempty"`
}

func (r *PlatformOnboardingRequest) BeforeCreate(tx *gorm.DB) error {
	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}
	return nil
}

func (PlatformOnboardingRequest) TableName() string { return "platform_onboarding_requests" }

// ─── Platform Audit Log ─────────────────────────────────────────────────────

// PlatformAuditLog records every platform-level action for accountability.
type PlatformAuditLog struct {
	ID         uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	AdminID    *uuid.UUID `gorm:"type:uuid;index" json:"adminId,omitempty"`
	Action     string     `gorm:"type:varchar(50);not null" json:"action"`
	EntityType string     `gorm:"type:varchar(50);not null" json:"entityType"`
	EntityID   *uuid.UUID `gorm:"type:uuid" json:"entityId,omitempty"`
	Details    string     `gorm:"type:text" json:"details,omitempty"`
	IPAddress  string     `gorm:"type:varchar(45)" json:"ipAddress,omitempty"`
	CreatedAt  time.Time  `gorm:"autoCreateTime;index" json:"createdAt"`

	// Relations
	Admin *PlatformAdmin `gorm:"foreignKey:AdminID" json:"admin,omitempty"`
}

func (l *PlatformAuditLog) BeforeCreate(tx *gorm.DB) error {
	if l.ID == uuid.Nil {
		l.ID = uuid.New()
	}
	return nil
}

func (PlatformAuditLog) TableName() string { return "platform_audit_logs" }
