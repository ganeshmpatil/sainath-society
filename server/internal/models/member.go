package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Member represents a pre-registered society member (seeded by admin)
// Members must complete registration to create login credentials
type Member struct {
	ID        uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name      string     `gorm:"type:varchar(100);not null" json:"name"`
	Mobile    string     `gorm:"type:varchar(15);uniqueIndex;not null" json:"mobile"`
	FlatID    *uuid.UUID `gorm:"type:uuid" json:"flatId,omitempty"`
	Role      Role       `gorm:"type:varchar(20);not null;default:'MEMBER'" json:"role"`
	Designation string   `gorm:"type:varchar(50)" json:"designation,omitempty"`

	// Registration status
	IsRegistered bool       `gorm:"default:false" json:"isRegistered"`
	RegisteredAt *time.Time `json:"registeredAt,omitempty"`
	UserID       *uuid.UUID `gorm:"type:uuid" json:"userId,omitempty"` // Link to User after registration (no FK to avoid circular dependency)

	// Admin who added this member
	AddedBy   *uuid.UUID `gorm:"type:uuid" json:"addedBy,omitempty"`
	IsActive  bool       `gorm:"default:true" json:"isActive"`

	// Audit
	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	Flat *Flat `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
}

func (m *Member) BeforeCreate(tx *gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}

func (Member) TableName() string {
	return "members"
}

// OTP represents a one-time password for verification
type OTP struct {
	ID        uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Mobile    string    `gorm:"type:varchar(15);not null;index" json:"mobile"`
	Code      string    `gorm:"type:varchar(6);not null" json:"-"`
	Purpose   string    `gorm:"type:varchar(20);not null" json:"purpose"` // "registration", "login", "reset_password"

	// Expiry and usage
	ExpiresAt  time.Time `gorm:"not null" json:"expiresAt"`
	IsUsed     bool      `gorm:"default:false" json:"isUsed"`
	UsedAt     *time.Time `json:"usedAt,omitempty"`

	// Tracking
	Attempts   int       `gorm:"default:0" json:"attempts"`
	MaxAttempts int      `gorm:"default:3" json:"maxAttempts"`

	// Audit
	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (o *OTP) BeforeCreate(tx *gorm.DB) error {
	if o.ID == uuid.Nil {
		o.ID = uuid.New()
	}
	return nil
}

func (OTP) TableName() string {
	return "otps"
}

// IsValid checks if OTP is still valid
func (o *OTP) IsValid() bool {
	return !o.IsUsed && time.Now().Before(o.ExpiresAt) && o.Attempts < o.MaxAttempts
}

// IsExpired checks if OTP has expired
func (o *OTP) IsExpired() bool {
	return time.Now().After(o.ExpiresAt)
}
