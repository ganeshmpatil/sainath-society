package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// MemberDocType classifies personal/identity documents
type MemberDocType string

const (
	MemberDocAadhaar           MemberDocType = "AADHAAR"
	MemberDocPanCard           MemberDocType = "PAN_CARD"
	MemberDocShareCertificate  MemberDocType = "SHARE_CERTIFICATE"
	MemberDocHouseRegistration MemberDocType = "HOUSE_REGISTRATION"
	MemberDocPassport          MemberDocType = "PASSPORT"
	MemberDocVoterID           MemberDocType = "VOTER_ID"
	MemberDocDrivingLicense    MemberDocType = "DRIVING_LICENSE"
	MemberDocOther             MemberDocType = "OTHER"
)

// MemberDocument stores a personal identity document with compressed binary
// data directly in the database. Each member sees only their own documents;
// admins can view all.
type MemberDocument struct {
	ID       uuid.UUID     `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	MemberID uuid.UUID     `gorm:"type:uuid;not null;index" json:"memberId"`
	FlatID   *uuid.UUID    `gorm:"type:uuid;index" json:"flatId,omitempty"`
	DocType  MemberDocType `gorm:"type:varchar(30);not null" json:"docType"`
	Title    string        `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr  string        `gorm:"type:varchar(200)" json:"titleMr,omitempty"`

	// File metadata
	FileName       string `gorm:"type:varchar(255);not null" json:"fileName"`
	MimeType       string `gorm:"type:varchar(100);not null" json:"mimeType"`
	OriginalSize   int64  `json:"originalSize"`
	CompressedSize int64  `json:"compressedSize"`

	// Compressed binary stored in DB (gzip)
	FileData []byte `gorm:"type:bytea;not null" json:"-"`

	// Lifecycle
	ExpiresAt *time.Time `json:"expiresAt,omitempty"`
	CreatedAt time.Time  `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time  `gorm:"autoUpdateTime" json:"updatedAt"`

	// Relations
	Member *Member `gorm:"foreignKey:MemberID" json:"member,omitempty"`
	Flat   *Flat   `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
}

func (d *MemberDocument) BeforeCreate(tx *gorm.DB) error {
	if d.ID == uuid.Nil {
		d.ID = uuid.New()
	}
	return nil
}

func (MemberDocument) TableName() string { return "soc_mitra_member_documents" }
