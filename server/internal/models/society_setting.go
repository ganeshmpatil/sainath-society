package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// SocietySetting stores key-value configuration for the society.
// Used for GST details, bank info, and other configurable values.
type SocietySetting struct {
	ID        uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Key       string    `gorm:"type:varchar(50);not null;uniqueIndex" json:"key"`
	Value     string    `gorm:"type:text;not null" json:"value"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (s *SocietySetting) BeforeCreate(tx *gorm.DB) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	return nil
}

func (SocietySetting) TableName() string { return "soc_mitra_society_settings" }

// Well-known setting keys
const (
	SettingGSTIN         = "gstin"
	SettingPAN           = "pan"
	SettingSocietyName   = "society_name"
	SettingSocietyAddr   = "society_address"
	SettingSACCode       = "sac_code"       // default: 9972
	SettingGSTRate       = "gst_rate"       // total GST %, e.g. 18
	SettingGSTThreshold  = "gst_threshold"  // per-flat monthly threshold, default 7500
	SettingInvoicePrefix = "invoice_prefix" // e.g. "INV"
)
