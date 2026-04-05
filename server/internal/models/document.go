package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// DocumentScope controls who can see a document without admin override.
type DocumentScope string

const (
	DocScopePublic   DocumentScope = "PUBLIC"    // visible to all members
	DocScopeMember   DocumentScope = "MEMBER"    // visible only to a specific member
	DocScopeCommittee DocumentScope = "COMMITTEE" // visible only to admins/committee
	DocScopeFlat     DocumentScope = "FLAT"      // visible to flat's owners/residents
)

// DocumentCategory classifies the nature of the document
type DocumentCategory string

const (
	DocCatLegal       DocumentCategory = "LEGAL"
	DocCatFinancial   DocumentCategory = "FINANCIAL"
	DocCatMeeting     DocumentCategory = "MEETING"
	DocCatCompliance  DocumentCategory = "COMPLIANCE"
	DocCatByLaw       DocumentCategory = "BYLAW"
	DocCatAudit       DocumentCategory = "AUDIT"
	DocCatInsurance   DocumentCategory = "INSURANCE"
	DocCatLicense     DocumentCategory = "LICENSE"
	DocCatCorrespondence DocumentCategory = "CORRESPONDENCE"
	DocCatOther       DocumentCategory = "OTHER"
)

// Document is a generic, centrally stored file in the document vault.
// Row-level access is applied via Scope + OwnerMemberID + FlatID.
// Admins always see everything; members see PUBLIC + their own (OwnerMemberID = actor) + their flat's docs.
type Document struct {
	ID          uuid.UUID        `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title       string           `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr     string           `gorm:"type:varchar(200)" json:"titleMr,omitempty"`
	Description string           `gorm:"type:text" json:"description,omitempty"`
	DescriptionMr string         `gorm:"type:text" json:"descriptionMr,omitempty"`

	Category DocumentCategory `gorm:"type:varchar(40);not null" json:"category"`
	Scope    DocumentScope    `gorm:"type:varchar(20);not null;default:'PUBLIC'" json:"scope"`

	// File metadata
	FileURL     string `gorm:"type:varchar(500);not null" json:"fileUrl"`
	FileName    string `gorm:"type:varchar(255);not null" json:"fileName"`
	FileSize    int64  `json:"fileSize"`
	MimeType    string `gorm:"type:varchar(100)" json:"mimeType,omitempty"`
	Checksum    string `gorm:"type:varchar(128)" json:"checksum,omitempty"` // SHA-256

	// Versioning
	Version     int        `gorm:"default:1" json:"version"`
	ParentDocID *uuid.UUID `gorm:"type:uuid;index" json:"parentDocId,omitempty"` // for versioning chain
	IsLatest    bool       `gorm:"default:true;index" json:"isLatest"`

	// Row-level access anchors (used together with Scope)
	OwnerMemberID *uuid.UUID `gorm:"type:uuid;index" json:"ownerMemberId,omitempty"`
	FlatID        *uuid.UUID `gorm:"type:uuid;index" json:"flatId,omitempty"`

	// Classification / search
	Tags       string `gorm:"type:text" json:"tags,omitempty"` // CSV
	Confidential bool `gorm:"default:false" json:"confidential"`

	// Lifecycle
	EffectiveFrom *time.Time `json:"effectiveFrom,omitempty"`
	ExpiresAt     *time.Time `json:"expiresAt,omitempty"`
	ArchivedAt    *time.Time `json:"archivedAt,omitempty"`

	// Audit
	UploadedByID uuid.UUID `gorm:"type:uuid;not null" json:"uploadedById"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	UploadedBy    *Member            `gorm:"foreignKey:UploadedByID" json:"uploadedBy,omitempty"`
	Flat          *Flat              `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
	AccessGrants  []DocumentAccess   `gorm:"foreignKey:DocumentID" json:"accessGrants,omitempty"`
}

func (d *Document) BeforeCreate(tx *gorm.DB) error {
	if d.ID == uuid.Nil {
		d.ID = uuid.New()
	}
	return nil
}

func (Document) TableName() string { return "soc_mitra_documents" }

// DocumentAccess lets admins explicitly grant extra members access to a scoped doc
// (overrides the default row-level ACL derived from Scope/OwnerMemberID/FlatID).
type DocumentAccess struct {
	ID         uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	DocumentID uuid.UUID `gorm:"type:uuid;not null;index" json:"documentId"`
	MemberID   uuid.UUID `gorm:"type:uuid;not null;index" json:"memberId"`
	GrantedBy  uuid.UUID `gorm:"type:uuid;not null" json:"grantedBy"`
	CanEdit    bool      `gorm:"default:false" json:"canEdit"`
	GrantedAt  time.Time `gorm:"autoCreateTime" json:"grantedAt"`
	ExpiresAt  *time.Time `json:"expiresAt,omitempty"`
}

func (DocumentAccess) TableName() string { return "soc_mitra_document_access_grants" }

// DocumentAuditLog tracks every view/download/edit for compliance
type DocumentAuditLog struct {
	ID         uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	DocumentID uuid.UUID `gorm:"type:uuid;not null;index" json:"documentId"`
	ActorID    uuid.UUID `gorm:"type:uuid;not null;index" json:"actorId"`
	Action     string    `gorm:"type:varchar(20);not null" json:"action"` // VIEW, DOWNLOAD, EDIT, DELETE
	IPAddress  string    `gorm:"type:varchar(45)" json:"ipAddress,omitempty"`
	CreatedAt  time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (DocumentAuditLog) TableName() string { return "soc_mitra_document_audit_logs" }
