package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// OwnershipType captures how the flat is held
type OwnershipType string

const (
	OwnershipTypeOwner    OwnershipType = "OWNER"
	OwnershipTypeCoOwner  OwnershipType = "CO_OWNER"
	OwnershipTypeNominee  OwnershipType = "NOMINEE"
	OwnershipTypeInherited OwnershipType = "INHERITED"
)

// MemberOwnership records a member's legal relationship to a flat.
// One flat may have multiple ownership rows (owner + co-owners + nominees).
type MemberOwnership struct {
	ID            uuid.UUID     `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	MemberID      uuid.UUID     `gorm:"type:uuid;not null;index" json:"memberId"`
	FlatID        uuid.UUID     `gorm:"type:uuid;not null;index" json:"flatId"`
	OwnershipType OwnershipType `gorm:"type:varchar(20);not null;default:'OWNER'" json:"ownershipType"`
	SharePercent  float64       `gorm:"type:decimal(5,2);default:100.00" json:"sharePercent"`

	// Legal/Share certificate details
	ShareCertNo    string     `gorm:"type:varchar(50)" json:"shareCertNo,omitempty"`
	SaleDeedNo     string     `gorm:"type:varchar(100)" json:"saleDeedNo,omitempty"`
	RegisteredDate *time.Time `json:"registeredDate,omitempty"`
	PossessionDate *time.Time `json:"possessionDate,omitempty"`

	// Agricultural/identity bindings
	PANNumber    string `gorm:"type:varchar(20)" json:"panNumber,omitempty"`
	AadhaarLast4 string `gorm:"type:varchar(4)" json:"aadhaarLast4,omitempty"`

	IsActive  bool      `gorm:"default:true" json:"isActive"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	Member    *Member            `gorm:"foreignKey:MemberID" json:"member,omitempty"`
	Flat      *Flat              `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
	Documents []HousingDocument  `gorm:"foreignKey:OwnershipID" json:"documents,omitempty"`
}

func (m *MemberOwnership) BeforeCreate(tx *gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}

func (MemberOwnership) TableName() string { return "soc_mitra_member_ownerships" }

// DocumentType enumerates allowed housing document kinds
type DocumentType string

const (
	DocumentSaleDeed        DocumentType = "SALE_DEED"
	DocumentShareCertificate DocumentType = "SHARE_CERTIFICATE"
	DocumentNOC             DocumentType = "NOC"
	DocumentIndexII         DocumentType = "INDEX_II"
	DocumentPropertyTax     DocumentType = "PROPERTY_TAX_RECEIPT"
	DocumentMaintenance     DocumentType = "MAINTENANCE_RECEIPT"
	DocumentOther           DocumentType = "OTHER"
)

// HousingDocument stores uploaded documents linked to an ownership record
type HousingDocument struct {
	ID          uuid.UUID    `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	OwnershipID uuid.UUID    `gorm:"type:uuid;not null;index" json:"ownershipId"`
	DocType     DocumentType `gorm:"type:varchar(40);not null" json:"docType"`
	Title       string       `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr     string       `gorm:"type:varchar(200)" json:"titleMr,omitempty"`
	FileURL     string       `gorm:"type:varchar(500);not null" json:"fileUrl"`
	FileSize    int64        `json:"fileSize"`
	MimeType    string       `gorm:"type:varchar(100)" json:"mimeType,omitempty"`
	IssuedDate  *time.Time   `json:"issuedDate,omitempty"`
	ExpiryDate  *time.Time   `json:"expiryDate,omitempty"`
	UploadedBy  uuid.UUID    `gorm:"type:uuid;not null" json:"uploadedBy"`
	CreatedAt   time.Time    `gorm:"autoCreateTime" json:"createdAt"`
}

func (h *HousingDocument) BeforeCreate(tx *gorm.DB) error {
	if h.ID == uuid.Nil {
		h.ID = uuid.New()
	}
	return nil
}

func (HousingDocument) TableName() string { return "soc_mitra_housing_documents" }
