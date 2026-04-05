package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type MovementType string

const (
	MovementMoveIn  MovementType = "MOVE_IN"
	MovementMoveOut MovementType = "MOVE_OUT"
)

type TenancyStatus string

const (
	TenancyPending  TenancyStatus = "PENDING"
	TenancyApproved TenancyStatus = "APPROVED"
	TenancyActive   TenancyStatus = "ACTIVE"
	TenancyExited   TenancyStatus = "EXITED"
	TenancyRejected TenancyStatus = "REJECTED"
)

// Tenant represents a non-owner occupant of a flat.
// Row-level access: flat's OwnerMemberID + ADMIN + the tenant themselves (if registered).
type Tenant struct {
	ID             uuid.UUID     `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	FlatID         uuid.UUID     `gorm:"type:uuid;not null;index" json:"flatId"`
	OwnerMemberID  uuid.UUID     `gorm:"type:uuid;not null;index" json:"ownerMemberId"` // flat owner (landlord)

	Name           string        `gorm:"type:varchar(100);not null" json:"name"`
	Mobile         string        `gorm:"type:varchar(15);not null" json:"mobile"`
	Email          string        `gorm:"type:varchar(255)" json:"email,omitempty"`
	AadhaarLast4   string        `gorm:"type:varchar(4)" json:"aadhaarLast4,omitempty"`
	PoliceVerified bool          `gorm:"default:false" json:"policeVerified"`
	VerificationDocURL string    `gorm:"type:varchar(500)" json:"verificationDocUrl,omitempty"`

	AgreementStart *time.Time    `json:"agreementStart,omitempty"`
	AgreementEnd   *time.Time    `json:"agreementEnd,omitempty"`
	MonthlyRent    float64       `gorm:"type:decimal(10,2)" json:"monthlyRent,omitempty"`
	Deposit        float64       `gorm:"type:decimal(10,2)" json:"deposit,omitempty"`
	FamilyCount    int           `gorm:"default:1" json:"familyCount"`

	Status         TenancyStatus `gorm:"type:varchar(20);not null;default:'PENDING'" json:"status"`
	ApprovedByID   *uuid.UUID    `gorm:"type:uuid" json:"approvedById,omitempty"`
	ApprovedAt     *time.Time    `json:"approvedAt,omitempty"`

	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Flat  *Flat   `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
	Owner *Member `gorm:"foreignKey:OwnerMemberID" json:"owner,omitempty"`
}

func (t *Tenant) BeforeCreate(tx *gorm.DB) error {
	if t.ID == uuid.Nil {
		t.ID = uuid.New()
	}
	return nil
}

func (Tenant) TableName() string { return "soc_mitra_tenants" }

// TenantMovement tracks physical move-in/move-out events for security and audit.
type TenantMovement struct {
	ID           uuid.UUID    `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	TenantID     uuid.UUID    `gorm:"type:uuid;not null;index" json:"tenantId"`
	FlatID       uuid.UUID    `gorm:"type:uuid;not null;index" json:"flatId"`
	MovementType MovementType `gorm:"type:varchar(20);not null" json:"movementType"`
	ScheduledAt  time.Time    `gorm:"not null" json:"scheduledAt"`
	ActualAt     *time.Time   `json:"actualAt,omitempty"`
	VehicleDetails string     `gorm:"type:varchar(200)" json:"vehicleDetails,omitempty"`
	Notes        string       `gorm:"type:text" json:"notes,omitempty"`
	ApprovedByID *uuid.UUID   `gorm:"type:uuid" json:"approvedById,omitempty"`
	CreatedAt    time.Time    `gorm:"autoCreateTime" json:"createdAt"`

	Tenant *Tenant `gorm:"foreignKey:TenantID" json:"tenant,omitempty"`
}

func (m *TenantMovement) BeforeCreate(tx *gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}

func (TenantMovement) TableName() string { return "soc_mitra_tenant_movements" }
