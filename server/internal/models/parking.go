package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ParkingSlotType string

const (
	SlotCar        ParkingSlotType = "CAR"
	SlotBike       ParkingSlotType = "BIKE"
	SlotCovered    ParkingSlotType = "COVERED"
	SlotOpen       ParkingSlotType = "OPEN"
	SlotVisitor    ParkingSlotType = "VISITOR"
)

// ParkingSlot represents a physical parking space in the society.
// AllocatedTo* fields are nullable: a slot may be unassigned.
type ParkingSlot struct {
	ID          uuid.UUID       `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	SlotNumber  string          `gorm:"type:varchar(20);uniqueIndex;not null" json:"slotNumber"`
	SlotType    ParkingSlotType `gorm:"type:varchar(20);not null" json:"slotType"`
	Location    string          `gorm:"type:varchar(100)" json:"location,omitempty"` // e.g. "Basement 1"

	// Allocation — nullable until assigned
	AllocatedToFlatID   *uuid.UUID `gorm:"type:uuid;index" json:"allocatedToFlatId,omitempty"`
	AllocatedToMemberID *uuid.UUID `gorm:"type:uuid;index" json:"allocatedToMemberId,omitempty"`
	AllocatedAt         *time.Time `json:"allocatedAt,omitempty"`

	IsActive  bool      `gorm:"default:true" json:"isActive"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Flat *Flat `gorm:"foreignKey:AllocatedToFlatID" json:"flat,omitempty"`
}

func (p *ParkingSlot) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (ParkingSlot) TableName() string { return "soc_mitra_parking_slots" }
