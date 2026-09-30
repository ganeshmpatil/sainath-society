package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// AMCContractStatus tracks the lifecycle of a contract.
type AMCContractStatus string

const (
	ContractActive  AMCContractStatus = "ACTIVE"
	ContractExpired AMCContractStatus = "EXPIRED"
	ContractRenewed AMCContractStatus = "RENEWED"
)

// ServiceType categorizes the type of service covered by the contract.
type ServiceType string

const (
	ServiceElevator     ServiceType = "ELEVATOR"
	ServiceFire         ServiceType = "FIRE_SAFETY"
	ServicePestControl  ServiceType = "PEST_CONTROL"
	ServiceWaterTank    ServiceType = "WATER_TANK"
	ServiceCCTV         ServiceType = "CCTV"
	ServiceGenerator    ServiceType = "GENERATOR"
	ServiceGarden       ServiceType = "GARDEN"
	ServiceHousekeeping ServiceType = "HOUSEKEEPING"
	ServicePlumbing     ServiceType = "PLUMBING"
	ServiceElectrical   ServiceType = "ELECTRICAL"
	ServiceOther        ServiceType = "OTHER"
)

// AMCContract represents a vendor service contract (Annual Maintenance Contract).
type AMCContract struct {
	ID             uuid.UUID         `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	VendorID       uuid.UUID         `gorm:"type:uuid;not null;index" json:"vendorId"`
	ServiceType    ServiceType       `gorm:"type:varchar(30);not null" json:"serviceType"`
	Description    string            `gorm:"type:varchar(300)" json:"description"`
	DescriptionMr  string            `gorm:"type:varchar(300)" json:"descriptionMr,omitempty"`
	ContractAmount float64           `gorm:"type:decimal(12,2);not null" json:"contractAmount"`
	PaymentTerms   string            `gorm:"type:varchar(100)" json:"paymentTerms,omitempty"` // Quarterly, Half-yearly, Annual
	StartDate      time.Time         `gorm:"not null" json:"startDate"`
	EndDate        time.Time         `gorm:"not null" json:"endDate"`
	ReminderDays   int               `gorm:"default:30" json:"reminderDays"` // days before expiry to send alert
	Status         AMCContractStatus `gorm:"type:varchar(20);not null;default:'ACTIVE'" json:"status"`
	Notes          string            `gorm:"type:text" json:"notes,omitempty"`
	CreatedByID    uuid.UUID         `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt      time.Time         `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt      time.Time         `gorm:"autoUpdateTime" json:"updatedAt"`

	Vendor *Vendor `gorm:"foreignKey:VendorID" json:"vendor,omitempty"`
}

func (a *AMCContract) BeforeCreate(tx *gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return nil
}

func (AMCContract) TableName() string { return "soc_mitra_amc_contracts" }

// ServiceLog records each service visit under a contract.
type ServiceLog struct {
	ID         uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	ContractID uuid.UUID `gorm:"type:uuid;not null;index" json:"contractId"`
	ServiceDate time.Time `gorm:"not null" json:"serviceDate"`
	Description string   `gorm:"type:text" json:"description"`
	TechnicianName string `gorm:"type:varchar(100)" json:"technicianName,omitempty"`
	Rating      int      `gorm:"default:0" json:"rating"` // 1-5
	Notes       string   `gorm:"type:text" json:"notes,omitempty"`
	LoggedByID  uuid.UUID `gorm:"type:uuid;not null" json:"loggedById"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (s *ServiceLog) BeforeCreate(tx *gorm.DB) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	return nil
}

func (ServiceLog) TableName() string { return "soc_mitra_service_logs" }
