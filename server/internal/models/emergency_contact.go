package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ContactCategory groups emergency contacts for display.
type ContactCategory string

const (
	ContactCategoryCommittee ContactCategory = "COMMITTEE"
	ContactCategoryEmergency ContactCategory = "EMERGENCY"
	ContactCategoryUtility   ContactCategory = "UTILITY"
	ContactCategoryOther     ContactCategory = "OTHER"
)

// EmergencyContact stores important phone numbers visible to all members.
type EmergencyContact struct {
	ID         uuid.UUID       `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name       string          `gorm:"type:varchar(100);not null" json:"name"`
	NameMr     string          `gorm:"type:varchar(100)" json:"nameMr,omitempty"`
	Category   ContactCategory `gorm:"type:varchar(20);not null;default:'OTHER'" json:"category"`
	Phone      string          `gorm:"type:varchar(20);not null" json:"phone"`
	AltPhone   string          `gorm:"type:varchar(20)" json:"altPhone,omitempty"`
	Role       string          `gorm:"type:varchar(50)" json:"role,omitempty"`
	RoleMr     string          `gorm:"type:varchar(50)" json:"roleMr,omitempty"`
	SortOrder  int             `gorm:"default:0" json:"sortOrder"`
	IsActive   bool            `gorm:"default:true" json:"isActive"`
	AddedByID  *uuid.UUID      `gorm:"type:uuid" json:"addedById,omitempty"`
	CreatedAt  time.Time       `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt  time.Time       `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (e *EmergencyContact) BeforeCreate(tx *gorm.DB) error {
	if e.ID == uuid.Nil {
		e.ID = uuid.New()
	}
	return nil
}

func (EmergencyContact) TableName() string {
	return "emergency_contacts"
}
