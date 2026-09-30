package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type VendorType string

const (
	VendorContractor   VendorType = "CONTRACTOR"
	VendorProfessional VendorType = "PROFESSIONAL"
	VendorEmployee     VendorType = "EMPLOYEE"
	VendorLandlord     VendorType = "LANDLORD"
	VendorOther        VendorType = "OTHER"
)

// Vendor represents a payee the society makes payments to.
type Vendor struct {
	ID         uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name       string     `gorm:"type:varchar(200);not null" json:"name"`
	NameMr     string     `gorm:"type:varchar(200)" json:"nameMr"`
	PAN        string     `gorm:"type:varchar(10)" json:"pan"`
	GSTIN      string     `gorm:"type:varchar(15)" json:"gstin"`
	VendorType VendorType `gorm:"type:varchar(20);not null" json:"vendorType"`
	Phone      string     `gorm:"type:varchar(15)" json:"phone"`
	Email      string     `gorm:"type:varchar(150)" json:"email"`
	Address    string     `gorm:"type:text" json:"address"`

	// TDS configuration
	TDSSection string  `gorm:"type:varchar(10)" json:"tdsSection"` // 194C, 194J, 194I, 192
	TDSRate    float64 `gorm:"type:decimal(5,2);default:0" json:"tdsRate"`

	IsActive    bool      `gorm:"not null;default:true" json:"isActive"`
	CreatedByID *uuid.UUID `gorm:"type:uuid" json:"createdById,omitempty"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (v *Vendor) BeforeCreate(tx *gorm.DB) error {
	if v.ID == uuid.Nil {
		v.ID = uuid.New()
	}
	// Auto-suggest TDS section based on vendor type
	if v.TDSSection == "" {
		switch v.VendorType {
		case VendorContractor:
			v.TDSSection = "194C"
			if v.TDSRate == 0 {
				v.TDSRate = 2.0 // default for firms/companies
			}
		case VendorProfessional:
			v.TDSSection = "194J"
			if v.TDSRate == 0 {
				v.TDSRate = 10.0
			}
		case VendorLandlord:
			v.TDSSection = "194I"
			if v.TDSRate == 0 {
				v.TDSRate = 10.0
			}
		case VendorEmployee:
			v.TDSSection = "192"
		}
	}
	// No PAN → higher rate of 20%
	if v.PAN == "" && v.TDSRate > 0 && v.TDSRate < 20 {
		v.TDSRate = 20.0
	}
	return nil
}

func (Vendor) TableName() string { return "soc_mitra_vendors" }
