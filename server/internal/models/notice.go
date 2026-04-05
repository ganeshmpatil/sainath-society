package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type NoticeCategory string

const (
	NoticeGeneral      NoticeCategory = "GENERAL"
	NoticeMaintenance  NoticeCategory = "MAINTENANCE"
	NoticeAGM          NoticeCategory = "AGM"
	NoticeEmergency    NoticeCategory = "EMERGENCY"
	NoticeFestival     NoticeCategory = "FESTIVAL"
	NoticeRuleChange   NoticeCategory = "RULE_CHANGE"
)

// Notice is a society-wide broadcast readable by all members.
type Notice struct {
	ID           uuid.UUID      `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title        string         `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr      string         `gorm:"type:varchar(200)" json:"titleMr,omitempty"`
	Body         string         `gorm:"type:text;not null" json:"body"`
	BodyMr       string         `gorm:"type:text" json:"bodyMr,omitempty"`
	Category     NoticeCategory `gorm:"type:varchar(30);not null;default:'GENERAL'" json:"category"`
	IsPinned     bool           `gorm:"default:false" json:"isPinned"`
	IsPublished  bool           `gorm:"default:true" json:"isPublished"`
	PublishAt    *time.Time     `json:"publishAt,omitempty"`
	ExpiresAt    *time.Time     `json:"expiresAt,omitempty"`
	AttachmentURL string        `gorm:"type:varchar(500)" json:"attachmentUrl,omitempty"`

	// Audit
	CreatedByID uuid.UUID `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	CreatedBy *Member `gorm:"foreignKey:CreatedByID" json:"createdBy,omitempty"`
}

func (n *Notice) BeforeCreate(tx *gorm.DB) error {
	if n.ID == uuid.Nil {
		n.ID = uuid.New()
	}
	return nil
}

func (Notice) TableName() string { return "soc_mitra_notices" }
