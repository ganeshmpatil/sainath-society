package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// FlatChargeOverride allows per-flat rate adjustments for specific charge heads.
// When present, the bill generator uses the override rate instead of the default.
// Setting Exempt=true skips the charge entirely for this flat.
type FlatChargeOverride struct {
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	FlatID       uuid.UUID `gorm:"type:uuid;not null;index:idx_flat_charge,unique" json:"flatId"`
	ChargeHeadID uuid.UUID `gorm:"type:uuid;not null;index:idx_flat_charge,unique" json:"chargeHeadId"`
	Rate         float64   `gorm:"type:decimal(10,2)" json:"rate"`     // override rate (used if not exempt)
	Exempt       bool      `gorm:"default:false" json:"exempt"`        // skip this charge for this flat
	Reason       string    `gorm:"type:varchar(200)" json:"reason"`    // why the override exists
	CreatedByID  uuid.UUID `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Flat       *Flat       `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
	ChargeHead *ChargeHead `gorm:"foreignKey:ChargeHeadID" json:"chargeHead,omitempty"`
}

func (o *FlatChargeOverride) BeforeCreate(tx *gorm.DB) error {
	if o.ID == uuid.Nil {
		o.ID = uuid.New()
	}
	return nil
}

func (FlatChargeOverride) TableName() string { return "soc_mitra_flat_charge_overrides" }
