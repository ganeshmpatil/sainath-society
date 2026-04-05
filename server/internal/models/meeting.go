package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type MeetingType string

const (
	MeetingAGM       MeetingType = "AGM"       // Annual General Meeting
	MeetingSGM       MeetingType = "SGM"       // Special General Meeting
	MeetingCommittee MeetingType = "COMMITTEE" // Committee only
	MeetingEmergency MeetingType = "EMERGENCY"
	MeetingReview    MeetingType = "REVIEW"
)

type MeetingStatus string

const (
	MeetingPlanned   MeetingStatus = "PLANNED"
	MeetingOngoing   MeetingStatus = "ONGOING"
	MeetingCompleted MeetingStatus = "COMPLETED"
	MeetingCancelled MeetingStatus = "CANCELLED"
)

// Meeting captures a society meeting with attendees, MoM and action items.
type Meeting struct {
	ID          uuid.UUID     `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title       string        `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr     string        `gorm:"type:varchar(200)" json:"titleMr,omitempty"`
	MeetingType MeetingType   `gorm:"type:varchar(20);not null" json:"meetingType"`
	Status      MeetingStatus `gorm:"type:varchar(20);not null;default:'PLANNED'" json:"status"`

	ScheduledAt time.Time  `gorm:"not null;index" json:"scheduledAt"`
	StartedAt   *time.Time `json:"startedAt,omitempty"`
	EndedAt     *time.Time `json:"endedAt,omitempty"`
	Location    string     `gorm:"type:varchar(200)" json:"location,omitempty"`
	MeetingURL  string     `gorm:"type:varchar(500)" json:"meetingUrl,omitempty"` // for virtual meetings

	// Agenda & Minutes
	Agenda         string `gorm:"type:text" json:"agenda,omitempty"`
	AgendaMr       string `gorm:"type:text" json:"agendaMr,omitempty"`
	MinutesOfMeeting string `gorm:"type:text" json:"minutesOfMeeting,omitempty"`
	MinutesOfMeetingMr string `gorm:"type:text" json:"minutesOfMeetingMr,omitempty"`
	MinutesLockedAt *time.Time `json:"minutesLockedAt,omitempty"` // once locked, cannot edit

	// Approval
	QuorumRequired int `gorm:"default:0" json:"quorumRequired"`
	QuorumAchieved bool `gorm:"default:false" json:"quorumAchieved"`

	// Audit
	CalledByID uuid.UUID `gorm:"type:uuid;not null" json:"calledById"`
	ChairedByID *uuid.UUID `gorm:"type:uuid" json:"chairedById,omitempty"`
	CreatedAt  time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt  time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Attendees  []MeetingAttendee   `gorm:"foreignKey:MeetingID" json:"attendees,omitempty"`
	ActionItems []MeetingActionItem `gorm:"foreignKey:MeetingID" json:"actionItems,omitempty"`
	Documents  []MeetingDocument   `gorm:"foreignKey:MeetingID" json:"documents,omitempty"`
}

func (m *Meeting) BeforeCreate(tx *gorm.DB) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	return nil
}

func (Meeting) TableName() string { return "soc_mitra_meetings" }

type AttendanceStatus string

const (
	AttendancePresent AttendanceStatus = "PRESENT"
	AttendanceAbsent  AttendanceStatus = "ABSENT"
	AttendanceExcused AttendanceStatus = "EXCUSED"
	AttendanceLate    AttendanceStatus = "LATE"
	AttendanceProxy   AttendanceStatus = "PROXY"
)

// MeetingAttendee records attendance for each member
type MeetingAttendee struct {
	ID        uuid.UUID        `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	MeetingID uuid.UUID        `gorm:"type:uuid;not null;index;uniqueIndex:uq_meeting_member" json:"meetingId"`
	MemberID  uuid.UUID        `gorm:"type:uuid;not null;index;uniqueIndex:uq_meeting_member" json:"memberId"`
	Status    AttendanceStatus `gorm:"type:varchar(10);not null" json:"status"`
	ProxyToID *uuid.UUID       `gorm:"type:uuid" json:"proxyToId,omitempty"`
	JoinedAt  *time.Time       `json:"joinedAt,omitempty"`
	LeftAt    *time.Time       `json:"leftAt,omitempty"`
	Remarks   string           `gorm:"type:varchar(500)" json:"remarks,omitempty"`

	Member *Member `gorm:"foreignKey:MemberID" json:"member,omitempty"`
}

func (MeetingAttendee) TableName() string { return "soc_mitra_meeting_attendees" }

type ActionItemStatus string

const (
	ActionOpen       ActionItemStatus = "OPEN"
	ActionInProgress ActionItemStatus = "IN_PROGRESS"
	ActionDone       ActionItemStatus = "DONE"
	ActionBlocked    ActionItemStatus = "BLOCKED"
	ActionDropped    ActionItemStatus = "DROPPED"
)

// MeetingActionItem is a to-do generated from a meeting; links to the Task system.
type MeetingActionItem struct {
	ID           uuid.UUID        `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	MeetingID    uuid.UUID        `gorm:"type:uuid;not null;index" json:"meetingId"`
	Title        string           `gorm:"type:varchar(300);not null" json:"title"`
	TitleMr      string           `gorm:"type:varchar(300)" json:"titleMr,omitempty"`
	Description  string           `gorm:"type:text" json:"description,omitempty"`
	OwnerMemberID uuid.UUID       `gorm:"type:uuid;not null;index" json:"ownerMemberId"`
	DueDate      *time.Time       `json:"dueDate,omitempty"`
	Status       ActionItemStatus `gorm:"type:varchar(20);not null;default:'OPEN'" json:"status"`
	LinkedTaskID *uuid.UUID       `gorm:"type:uuid" json:"linkedTaskId,omitempty"`
	CreatedAt    time.Time        `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time        `gorm:"autoUpdateTime" json:"updatedAt"`

	Owner *Member `gorm:"foreignKey:OwnerMemberID" json:"owner,omitempty"`
}

func (MeetingActionItem) TableName() string { return "soc_mitra_meeting_action_items" }

// MeetingDocument links documents to a meeting (agenda PDF, presentations, signed MoM)
type MeetingDocument struct {
	ID         uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	MeetingID  uuid.UUID `gorm:"type:uuid;not null;index" json:"meetingId"`
	DocumentID uuid.UUID `gorm:"type:uuid;not null;index" json:"documentId"`
	DocRole    string    `gorm:"type:varchar(30);not null" json:"docRole"` // AGENDA, MOM, PRESENTATION, SIGNED_MOM
	CreatedAt  time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (MeetingDocument) TableName() string { return "soc_mitra_meeting_documents" }
