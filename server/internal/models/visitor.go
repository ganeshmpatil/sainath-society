package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// VisitorType categorizes visitors.
type VisitorType string

const (
	VisitorGuest       VisitorType = "GUEST"
	VisitorDelivery    VisitorType = "DELIVERY"
	VisitorCab         VisitorType = "CAB"
	VisitorDomesticHelp VisitorType = "DOMESTIC_HELP"
	VisitorMaintenance VisitorType = "MAINTENANCE"
	VisitorOther       VisitorType = "OTHER"
)

// VisitorStatus tracks entry lifecycle.
type VisitorStatus string

const (
	VisitorPending  VisitorStatus = "PENDING"
	VisitorApproved VisitorStatus = "APPROVED"
	VisitorCheckedIn VisitorStatus = "CHECKED_IN"
	VisitorCheckedOut VisitorStatus = "CHECKED_OUT"
	VisitorRejected VisitorStatus = "REJECTED"
)

// Visitor represents a visitor entry at the society gate.
type Visitor struct {
	ID          uuid.UUID     `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name        string        `gorm:"type:varchar(100);not null" json:"name"`
	Phone       string        `gorm:"type:varchar(15)" json:"phone,omitempty"`
	VisitorType VisitorType   `gorm:"type:varchar(20);not null;default:'GUEST'" json:"visitorType"`
	Purpose     string        `gorm:"type:varchar(200)" json:"purpose,omitempty"`
	FlatID      uuid.UUID     `gorm:"type:uuid;not null;index" json:"flatId"`
	FlatNo      string        `gorm:"type:varchar(10);not null" json:"flatNo"`
	VehicleNo   string        `gorm:"type:varchar(20)" json:"vehicleNo,omitempty"`
	CompanyName string        `gorm:"type:varchar(100)" json:"companyName,omitempty"` // delivery/cab company
	Status      VisitorStatus `gorm:"type:varchar(20);not null;default:'PENDING'" json:"status"`
	EntryTime   *time.Time    `json:"entryTime,omitempty"`
	ExitTime    *time.Time    `json:"exitTime,omitempty"`
	ApprovedBy  *uuid.UUID    `gorm:"type:uuid" json:"approvedBy,omitempty"`
	RejectedBy  *uuid.UUID    `gorm:"type:uuid" json:"rejectedBy,omitempty"`
	RejectReason string       `gorm:"type:varchar(200)" json:"rejectReason,omitempty"`
	Notes       string        `gorm:"type:text" json:"notes,omitempty"`
	CreatedByID uuid.UUID     `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt   time.Time     `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time     `gorm:"autoUpdateTime" json:"updatedAt"`

	Flat *Flat `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
}

func (v *Visitor) BeforeCreate(tx *gorm.DB) error {
	if v.ID == uuid.Nil {
		v.ID = uuid.New()
	}
	return nil
}

func (Visitor) TableName() string { return "soc_mitra_visitors" }

// FrequentVisitor is a pre-approved recurring visitor (maid, cook, driver, etc.).
type FrequentVisitor struct {
	ID          uuid.UUID   `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name        string      `gorm:"type:varchar(100);not null" json:"name"`
	NameMr      string      `gorm:"type:varchar(100)" json:"nameMr,omitempty"`
	Phone       string      `gorm:"type:varchar(15)" json:"phone,omitempty"`
	VisitorType VisitorType `gorm:"type:varchar(20);not null;default:'DOMESTIC_HELP'" json:"visitorType"`
	FlatID      uuid.UUID   `gorm:"type:uuid;not null;index" json:"flatId"`
	FlatNo      string      `gorm:"type:varchar(10);not null" json:"flatNo"`
	Role        string      `gorm:"type:varchar(50)" json:"role,omitempty"` // Maid, Cook, Driver, etc.
	RoleMr      string      `gorm:"type:varchar(50)" json:"roleMr,omitempty"`
	IsActive    bool        `gorm:"default:true" json:"isActive"`
	IsBlacklisted bool      `gorm:"default:false" json:"isBlacklisted"`
	BlacklistReason string  `gorm:"type:varchar(200)" json:"blacklistReason,omitempty"`
	CreatedByID uuid.UUID   `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt   time.Time   `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time   `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (f *FrequentVisitor) BeforeCreate(tx *gorm.DB) error {
	if f.ID == uuid.Nil {
		f.ID = uuid.New()
	}
	return nil
}

func (FrequentVisitor) TableName() string { return "soc_mitra_frequent_visitors" }
