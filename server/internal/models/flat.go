package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Wing represents a building wing
type Wing struct {
	ID        uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name      string    `gorm:"type:varchar(10);not null;uniqueIndex" json:"name"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (Wing) TableName() string {
	return "wings"
}

// Flat represents a residential unit
type Flat struct {
	ID           uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	FlatNumber   string     `gorm:"type:varchar(20);not null;uniqueIndex" json:"flatNumber"`
	WingID       *uuid.UUID `gorm:"type:uuid" json:"wingId,omitempty"`
	Floor        int        `gorm:"not null" json:"floor"`
	AreaSqft     float64    `gorm:"type:decimal(10,2)" json:"areaSqft"`
	OwnerName    string     `gorm:"type:varchar(100)" json:"ownerName"`
	ShareCertNo  string     `gorm:"type:varchar(50)" json:"shareCertNo,omitempty"`
	NomineeName  string     `gorm:"type:varchar(100)" json:"nomineeName,omitempty"`
	PurchaseDate *time.Time `json:"purchaseDate,omitempty"`
	CreatedAt    time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	Wing *Wing `gorm:"foreignKey:WingID" json:"wing,omitempty"`
}

func (f *Flat) BeforeCreate(tx *gorm.DB) error {
	if f.ID == uuid.Nil {
		f.ID = uuid.New()
	}
	return nil
}

func (Flat) TableName() string {
	return "flats"
}
