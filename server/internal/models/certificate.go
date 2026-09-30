package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// CertificateType categorizes society certificates.
type CertificateType string

const (
	CertNoDues CertificateType = "NO_DUES"
	CertNOC    CertificateType = "NOC"
)

// CertificateStatus tracks the lifecycle.
type CertificateStatus string

const (
	CertRequested CertificateStatus = "REQUESTED"
	CertApproved  CertificateStatus = "APPROVED"
	CertRejected  CertificateStatus = "REJECTED"
)

// Certificate stores generated NOCs and No Dues certificates.
type Certificate struct {
	ID            uuid.UUID         `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	CertNo        string            `gorm:"type:varchar(30);uniqueIndex;not null" json:"certNo"`
	Type          CertificateType   `gorm:"type:varchar(20);not null" json:"type"`
	Status        CertificateStatus `gorm:"type:varchar(20);not null;default:'REQUESTED'" json:"status"`
	FlatID        uuid.UUID         `gorm:"type:uuid;not null;index" json:"flatId"`
	MemberID      uuid.UUID         `gorm:"type:uuid;not null;index" json:"memberId"`
	Purpose       string            `gorm:"type:varchar(200)" json:"purpose,omitempty"`        // e.g. "Flat sale", "Bank loan", "Passport"
	BuyerName     string            `gorm:"type:varchar(100)" json:"buyerName,omitempty"`      // for NOC
	SaleAmount    float64           `gorm:"type:decimal(12,2)" json:"saleAmount,omitempty"`    // for NOC
	TransferFee   float64           `gorm:"type:decimal(10,2)" json:"transferFee,omitempty"`   // for NOC
	PendingAmount float64           `gorm:"type:decimal(12,2)" json:"pendingAmount"`           // dues at time of request
	IssueDate     *time.Time        `json:"issueDate,omitempty"`
	ValidUntil    *time.Time        `json:"validUntil,omitempty"`
	RejectionNote string            `gorm:"type:text" json:"rejectionNote,omitempty"`
	RequestedByID uuid.UUID         `gorm:"type:uuid;not null" json:"requestedById"`
	ApprovedByID  *uuid.UUID        `gorm:"type:uuid" json:"approvedById,omitempty"`
	CreatedAt     time.Time         `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt     time.Time         `gorm:"autoUpdateTime" json:"updatedAt"`

	Flat   *Flat   `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
	Member *Member `gorm:"foreignKey:MemberID" json:"member,omitempty"`
}

func (c *Certificate) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}

func (Certificate) TableName() string { return "soc_mitra_certificates" }
