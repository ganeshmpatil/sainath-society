package models

import (
	"time"

	"github.com/google/uuid"
)

// MemberPhoto stores the profile photo for a member in a separate table
// to keep the photo blob out of member list queries.
type MemberPhoto struct {
	TenantScope
	MemberID  uuid.UUID `gorm:"type:uuid;primary_key" json:"memberId"`
	PhotoData []byte    `gorm:"type:bytea;not null" json:"-"`
	MimeType  string    `gorm:"type:varchar(100);not null" json:"mimeType"`
	Size      int64     `json:"size"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (MemberPhoto) TableName() string { return "soc_mitra_member_photos" }
