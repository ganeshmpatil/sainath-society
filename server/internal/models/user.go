package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Role represents user roles
type Role string

const (
	RoleMember Role = "MEMBER"
	RoleAdmin  Role = "ADMIN"
)

// User represents login credentials for a registered member
type User struct {
	ID           uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Email        string     `gorm:"type:varchar(255);uniqueIndex;not null" json:"email"`
	Mobile       string     `gorm:"type:varchar(15);uniqueIndex;not null" json:"mobile"`
	PasswordHash string     `gorm:"type:varchar(255);not null" json:"-"`

	// Link to pre-registered member
	MemberID     uuid.UUID  `gorm:"type:uuid;not null;uniqueIndex" json:"memberId"`

	IsActive     bool       `gorm:"default:true" json:"isActive"`

	// Security
	FailedLoginAttempts int        `gorm:"default:0" json:"-"`
	LockedUntil         *time.Time `json:"-"`
	PasswordChangedAt   *time.Time `json:"-"`
	MustChangePassword  bool       `gorm:"default:false" json:"mustChangePassword"`

	// Refresh Token
	RefreshTokenHash      string     `gorm:"type:varchar(255)" json:"-"`
	RefreshTokenExpiresAt *time.Time `json:"-"`

	// Audit
	LastLoginAt *time.Time `json:"lastLoginAt,omitempty"`
	LastLoginIP string     `gorm:"type:varchar(45)" json:"-"`
	CreatedAt   time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	Member *Member `gorm:"foreignKey:MemberID" json:"member,omitempty"`
}

func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	return nil
}

// IsLocked checks if the account is currently locked
func (u *User) IsLocked() bool {
	if u.LockedUntil == nil {
		return false
	}
	return time.Now().Before(*u.LockedUntil)
}

// IncrementFailedAttempts increments failed login attempts and locks account if needed
func (u *User) IncrementFailedAttempts() {
	u.FailedLoginAttempts++
	if u.FailedLoginAttempts >= 5 {
		lockUntil := time.Now().Add(30 * time.Minute)
		u.LockedUntil = &lockUntil
	}
}

// ResetFailedAttempts resets the failed login counter
func (u *User) ResetFailedAttempts() {
	u.FailedLoginAttempts = 0
	u.LockedUntil = nil
}

// TableName specifies the table name for User
func (User) TableName() string {
	return "users"
}
