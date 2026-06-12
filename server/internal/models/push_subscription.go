package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// PushSubscription stores a Web Push subscription for a member's browser.
// A member may have multiple subscriptions (multiple devices / browsers).
type PushSubscription struct {
	ID        uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	MemberID  uuid.UUID `gorm:"type:uuid;not null;index" json:"memberId"`
	Endpoint  string    `gorm:"type:text;not null;uniqueIndex" json:"endpoint"`
	KeyP256dh string    `gorm:"type:varchar(200);not null" json:"keyP256dh"`
	KeyAuth   string    `gorm:"type:varchar(100);not null" json:"keyAuth"`
	UserAgent string    `gorm:"type:varchar(300)" json:"userAgent,omitempty"`
	IsActive  bool      `gorm:"default:true" json:"isActive"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (p *PushSubscription) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (PushSubscription) TableName() string {
	return "push_subscriptions"
}
