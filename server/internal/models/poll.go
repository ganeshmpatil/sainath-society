package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PollStatus string

const (
	PollDraft     PollStatus = "DRAFT"
	PollActive    PollStatus = "ACTIVE"
	PollClosed    PollStatus = "CLOSED"
	PollCancelled PollStatus = "CANCELLED"
)

// Poll is a society-wide vote. One vote per flat is enforced via a unique
// index on (poll_id, flat_id) in soc_mitra_poll_votes.
type Poll struct {
	ID          uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title       string     `gorm:"type:varchar(300);not null" json:"title"`
	TitleMr     string     `gorm:"type:varchar(300)" json:"titleMr,omitempty"`
	Description string     `gorm:"type:text" json:"description,omitempty"`
	DescriptionMr string   `gorm:"type:text" json:"descriptionMr,omitempty"`
	Status      PollStatus `gorm:"type:varchar(20);not null;default:'DRAFT'" json:"status"`

	StartsAt time.Time  `gorm:"not null" json:"startsAt"`
	EndsAt   time.Time  `gorm:"not null" json:"endsAt"`
	IsAnonymous bool     `gorm:"default:false" json:"isAnonymous"`

	CreatedByID uuid.UUID `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Options []PollOption `gorm:"foreignKey:PollID" json:"options,omitempty"`
}

func (p *Poll) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (Poll) TableName() string { return "soc_mitra_polls" }

// PollOption is a single choice within a poll.
type PollOption struct {
	ID       uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	PollID   uuid.UUID `gorm:"type:uuid;not null;index" json:"pollId"`
	OptionText   string `gorm:"type:varchar(300);not null" json:"optionText"`
	OptionTextMr string `gorm:"type:varchar(300)" json:"optionTextMr,omitempty"`
	Order    int       `gorm:"default:0" json:"order"`
	VoteCount int      `gorm:"default:0" json:"voteCount"`
}

func (PollOption) TableName() string { return "soc_mitra_poll_options" }

// PollVote records a single vote. One vote per flat per poll.
type PollVote struct {
	ID         uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	PollID     uuid.UUID `gorm:"type:uuid;not null;index;uniqueIndex:uq_poll_flat" json:"pollId"`
	FlatID     uuid.UUID `gorm:"type:uuid;not null;index;uniqueIndex:uq_poll_flat" json:"flatId"`
	OptionID   uuid.UUID `gorm:"type:uuid;not null;index" json:"optionId"`
	VotedByID  uuid.UUID `gorm:"type:uuid;not null" json:"votedById"`
	CreatedAt  time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (PollVote) TableName() string { return "soc_mitra_poll_votes" }
