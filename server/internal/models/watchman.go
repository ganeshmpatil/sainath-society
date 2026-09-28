package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Watchman represents a security guard assigned to the society.
// Admin-only create/update/delete; all members can read.
type Watchman struct {
	ID            uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name          string    `gorm:"type:varchar(100);not null" json:"name"`
	NameMr        string    `gorm:"type:varchar(100)" json:"nameMr,omitempty"`
	Mobile        string    `gorm:"type:varchar(15);not null" json:"mobile"`
	DutyStartTime string    `gorm:"type:varchar(5);not null" json:"dutyStartTime"` // HH:MM
	DutyEndTime   string    `gorm:"type:varchar(5);not null" json:"dutyEndTime"`   // HH:MM
	IsActive      bool      `gorm:"default:true" json:"isActive"`
	CreatedAt     time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt     time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (w *Watchman) BeforeCreate(tx *gorm.DB) error {
	if w.ID == uuid.Nil {
		w.ID = uuid.New()
	}
	return nil
}

func (Watchman) TableName() string { return "soc_mitra_watchmen" }
