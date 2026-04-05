package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type SuggestionStatus string

const (
	SuggestionProposed  SuggestionStatus = "PROPOSED"
	SuggestionUnder     SuggestionStatus = "UNDER_REVIEW"
	SuggestionAccepted  SuggestionStatus = "ACCEPTED"
	SuggestionRejected  SuggestionStatus = "REJECTED"
	SuggestionImplemented SuggestionStatus = "IMPLEMENTED"
)

// Suggestion is a member-raised idea for society improvement.
// Visible to everyone; each member can upvote once.
type Suggestion struct {
	ID          uuid.UUID        `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title       string           `gorm:"type:varchar(300);not null" json:"title"`
	TitleMr     string           `gorm:"type:varchar(300)" json:"titleMr,omitempty"`
	Description string           `gorm:"type:text;not null" json:"description"`
	DescriptionMr string         `gorm:"type:text" json:"descriptionMr,omitempty"`
	Category    string           `gorm:"type:varchar(50)" json:"category,omitempty"`

	RaisedByMemberID uuid.UUID   `gorm:"type:uuid;not null;index" json:"raisedByMemberId"`
	Status           SuggestionStatus `gorm:"type:varchar(30);not null;default:'PROPOSED'" json:"status"`
	UpvoteCount      int         `gorm:"default:0" json:"upvoteCount"`

	AdminResponse    string `gorm:"type:text" json:"adminResponse,omitempty"`
	AdminResponseMr  string `gorm:"type:text" json:"adminResponseMr,omitempty"`
	RespondedByID    *uuid.UUID `gorm:"type:uuid" json:"respondedById,omitempty"`
	RespondedAt      *time.Time `json:"respondedAt,omitempty"`

	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	RaisedBy *Member `gorm:"foreignKey:RaisedByMemberID" json:"raisedBy,omitempty"`
}

func (s *Suggestion) BeforeCreate(tx *gorm.DB) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	return nil
}

func (Suggestion) TableName() string { return "soc_mitra_suggestions" }

// SuggestionUpvote tracks who upvoted what (one row per member per suggestion).
type SuggestionUpvote struct {
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	SuggestionID uuid.UUID `gorm:"type:uuid;not null;index;uniqueIndex:uq_suggestion_member" json:"suggestionId"`
	MemberID     uuid.UUID `gorm:"type:uuid;not null;index;uniqueIndex:uq_suggestion_member" json:"memberId"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (SuggestionUpvote) TableName() string { return "soc_mitra_suggestion_upvotes" }
