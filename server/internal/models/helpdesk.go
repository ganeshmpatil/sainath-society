package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// HelpdeskCategory categorizes helpdesk tickets.
type HelpdeskCategory string

const (
	HelpdeskPlumbing    HelpdeskCategory = "PLUMBING"
	HelpdeskElectrical  HelpdeskCategory = "ELECTRICAL"
	HelpdeskParking     HelpdeskCategory = "PARKING"
	HelpdeskWater       HelpdeskCategory = "WATER"
	HelpdeskCleanliness HelpdeskCategory = "CLEANLINESS"
	HelpdeskNoise       HelpdeskCategory = "NOISE"
	HelpdeskGeneral     HelpdeskCategory = "GENERAL"
	HelpdeskOther       HelpdeskCategory = "OTHER"
)

// HelpdeskPriority defines ticket urgency.
type HelpdeskPriority string

const (
	HelpdeskPriorityLow    HelpdeskPriority = "LOW"
	HelpdeskPriorityMedium HelpdeskPriority = "MEDIUM"
	HelpdeskPriorityHigh   HelpdeskPriority = "HIGH"
	HelpdeskPriorityUrgent HelpdeskPriority = "URGENT"
)

// HelpdeskStatus tracks the lifecycle of a ticket.
type HelpdeskStatus string

const (
	TicketOpen       HelpdeskStatus = "OPEN"
	TicketInProgress HelpdeskStatus = "IN_PROGRESS"
	TicketResolved   HelpdeskStatus = "RESOLVED"
	TicketClosed     HelpdeskStatus = "CLOSED"
)

// HelpdeskTicket represents a helpdesk / internal messaging ticket.
type HelpdeskTicket struct {
	ID           uuid.UUID        `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	TicketNo     string           `gorm:"type:varchar(10);uniqueIndex;not null" json:"ticketNo"`
	Subject      string           `gorm:"type:varchar(200);not null" json:"subject"`
	Description  string           `gorm:"type:text;not null" json:"description"`
	Category     HelpdeskCategory `gorm:"type:varchar(20);not null" json:"category"`
	Priority     HelpdeskPriority `gorm:"type:varchar(10);not null;default:'MEDIUM'" json:"priority"`
	Status       HelpdeskStatus   `gorm:"type:varchar(20);not null;default:'OPEN'" json:"status"`
	FlatID       uuid.UUID        `gorm:"type:uuid;index;not null" json:"flatId"`
	FlatNo       string           `gorm:"type:varchar(20);not null" json:"flatNo"`
	RaisedByID   uuid.UUID        `gorm:"type:uuid;not null" json:"raisedById"`
	AssignedToID *uuid.UUID       `gorm:"type:uuid" json:"assignedToId,omitempty"`
	ResolvedAt   *time.Time       `json:"resolvedAt,omitempty"`
	ClosedAt     *time.Time       `json:"closedAt,omitempty"`
	CreatedAt    time.Time        `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time        `gorm:"autoUpdateTime" json:"updatedAt"`

	Messages []HelpdeskMessage `gorm:"foreignKey:TicketID" json:"messages,omitempty"`
}

func (t *HelpdeskTicket) BeforeCreate(tx *gorm.DB) error {
	if t.ID == uuid.Nil {
		t.ID = uuid.New()
	}
	return nil
}

func (HelpdeskTicket) TableName() string { return "soc_mitra_helpdesk_tickets" }

// HelpdeskMessage is a single message/note within a ticket thread.
type HelpdeskMessage struct {
	ID         uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	TicketID   uuid.UUID `gorm:"type:uuid;not null;index" json:"ticketId"`
	SenderID   uuid.UUID `gorm:"type:uuid;not null" json:"senderId"`
	SenderName string    `gorm:"type:varchar(100);not null" json:"senderName"`
	SenderRole string    `gorm:"type:varchar(10);not null" json:"senderRole"` // MEMBER or ADMIN
	Body       string    `gorm:"type:text;not null" json:"body"`
	IsInternal bool      `gorm:"default:false" json:"isInternal"`
	CreatedAt  time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (m *HelpdeskMessage) BeforeCreate(tx *gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}

func (HelpdeskMessage) TableName() string { return "soc_mitra_helpdesk_messages" }
