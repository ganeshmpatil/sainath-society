package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type VehicleType string

const (
	VehicleCar        VehicleType = "CAR"
	VehicleBike       VehicleType = "BIKE"
	VehicleBicycle    VehicleType = "BICYCLE"
	VehicleCommercial VehicleType = "COMMERCIAL"
	VehicleEV         VehicleType = "EV"
	VehicleOther      VehicleType = "OTHER"
)

// Vehicle registered under a society member.
// Row-level access: OwnerMemberID + ADMIN.
type Vehicle struct {
	ID                uuid.UUID   `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	OwnerMemberID     uuid.UUID   `gorm:"type:uuid;not null;index" json:"ownerMemberId"`
	FlatID            *uuid.UUID  `gorm:"type:uuid;index" json:"flatId,omitempty"`
	RegistrationNo    string      `gorm:"type:varchar(20);uniqueIndex;not null" json:"registrationNo"`
	VehicleType       VehicleType `gorm:"type:varchar(20);not null" json:"vehicleType"`
	Make              string      `gorm:"type:varchar(50)" json:"make,omitempty"`
	Model             string      `gorm:"type:varchar(50)" json:"model,omitempty"`
	Color             string      `gorm:"type:varchar(30)" json:"color,omitempty"`
	ParkingSlot       string      `gorm:"type:varchar(20)" json:"parkingSlot,omitempty"`
	StickerNo         string      `gorm:"type:varchar(20)" json:"stickerNo,omitempty"`
	InsuranceExpiry   *time.Time  `json:"insuranceExpiry,omitempty"`
	PUCExpiry         *time.Time  `json:"pucExpiry,omitempty"`
	IsActive          bool        `gorm:"default:true" json:"isActive"`
	CreatedAt         time.Time   `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt         time.Time   `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	Owner *Member `gorm:"foreignKey:OwnerMemberID" json:"owner,omitempty"`
	Flat  *Flat   `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
}

func (v *Vehicle) BeforeCreate(tx *gorm.DB) error {
	if v.ID == uuid.Nil {
		v.ID = uuid.New()
	}
	return nil
}

func (Vehicle) TableName() string { return "soc_mitra_vehicles" }
