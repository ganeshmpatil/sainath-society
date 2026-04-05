package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type EventType string

const (
	EventFestival    EventType = "FESTIVAL"
	EventCultural    EventType = "CULTURAL"
	EventMaintenance EventType = "MAINTENANCE"
	EventMeeting     EventType = "MEETING"
	EventSports      EventType = "SPORTS"
	EventOther       EventType = "OTHER"
)

type EventStatus string

const (
	EventScheduled EventStatus = "SCHEDULED"
	EventOngoing   EventStatus = "ONGOING"
	EventCompleted EventStatus = "COMPLETED"
	EventCancelled EventStatus = "CANCELLED"
)

// Event represents an upcoming society event (open to all members).
type Event struct {
	ID          uuid.UUID   `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title       string      `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr     string      `gorm:"type:varchar(200)" json:"titleMr,omitempty"`
	Description string      `gorm:"type:text" json:"description,omitempty"`
	DescriptionMr string    `gorm:"type:text" json:"descriptionMr,omitempty"`
	EventType   EventType   `gorm:"type:varchar(20);not null" json:"eventType"`
	Status      EventStatus `gorm:"type:varchar(20);not null;default:'SCHEDULED'" json:"status"`

	StartTime time.Time `gorm:"not null;index" json:"startTime"`
	EndTime   time.Time `gorm:"not null" json:"endTime"`
	Location  string    `gorm:"type:varchar(200)" json:"location,omitempty"`

	MaxAttendees   int  `json:"maxAttendees,omitempty"`
	IsRSVPRequired bool `gorm:"default:false" json:"isRsvpRequired"`

	OrganizerID uuid.UUID `gorm:"type:uuid;not null" json:"organizerId"`
	BannerURL   string    `gorm:"type:varchar(500)" json:"bannerUrl,omitempty"`

	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Organizer *Member       `gorm:"foreignKey:OrganizerID" json:"organizer,omitempty"`
	RSVPs     []EventRSVP   `gorm:"foreignKey:EventID" json:"rsvps,omitempty"`
}

func (e *Event) BeforeCreate(tx *gorm.DB) error {
	if e.ID == uuid.Nil {
		e.ID = uuid.New()
	}
	return nil
}

func (Event) TableName() string { return "soc_mitra_events" }

type RSVPStatus string

const (
	RSVPYes   RSVPStatus = "YES"
	RSVPNo    RSVPStatus = "NO"
	RSVPMaybe RSVPStatus = "MAYBE"
)

// EventRSVP captures attendee confirmation
type EventRSVP struct {
	ID         uuid.UUID  `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	EventID    uuid.UUID  `gorm:"type:uuid;not null;index;uniqueIndex:uq_event_member" json:"eventId"`
	MemberID   uuid.UUID  `gorm:"type:uuid;not null;index;uniqueIndex:uq_event_member" json:"memberId"`
	Status     RSVPStatus `gorm:"type:varchar(10);not null" json:"status"`
	GuestCount int        `gorm:"default:0" json:"guestCount"`
	RespondedAt time.Time `gorm:"autoCreateTime" json:"respondedAt"`
}

func (EventRSVP) TableName() string { return "soc_mitra_event_rsvps" }
