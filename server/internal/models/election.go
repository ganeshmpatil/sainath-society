package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ElectionStatus represents the lifecycle state of an election.
type ElectionStatus string

const (
	ElectionUpcoming        ElectionStatus = "UPCOMING"
	ElectionNominationsOpen ElectionStatus = "NOMINATIONS_OPEN"
	ElectionVotingOpen      ElectionStatus = "VOTING_OPEN"
	ElectionCompleted       ElectionStatus = "COMPLETED"
	ElectionCancelled       ElectionStatus = "CANCELLED"
)

// CandidateStatus represents the state of a candidate nomination.
type CandidateStatus string

const (
	CandidateNominated CandidateStatus = "NOMINATED"
	CandidateApproved  CandidateStatus = "APPROVED"
	CandidateRejected  CandidateStatus = "REJECTED"
	CandidateWithdrawn CandidateStatus = "WITHDRAWN"
)

// Election represents a society committee election.
type Election struct {
	ID                  uuid.UUID      `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title               string         `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr             string         `gorm:"type:varchar(200)" json:"titleMr,omitempty"`
	Description         string         `gorm:"type:text" json:"description,omitempty"`
	Status              ElectionStatus `gorm:"type:varchar(20);not null;default:'UPCOMING'" json:"status"`
	NominationStartDate time.Time      `gorm:"not null" json:"nominationStartDate"`
	NominationEndDate   time.Time      `gorm:"not null" json:"nominationEndDate"`
	VotingStartDate     time.Time      `gorm:"not null" json:"votingStartDate"`
	VotingEndDate       time.Time      `gorm:"not null" json:"votingEndDate"`
	ResultDeclaredAt    *time.Time     `json:"resultDeclaredAt,omitempty"`
	CreatedByID         uuid.UUID      `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt           time.Time      `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt           time.Time      `gorm:"autoUpdateTime" json:"updatedAt"`

	Positions  []ElectionPosition  `gorm:"foreignKey:ElectionID" json:"positions,omitempty"`
	Candidates []ElectionCandidate `gorm:"foreignKey:ElectionID" json:"candidates,omitempty"`
	Votes      []ElectionVote      `gorm:"foreignKey:ElectionID" json:"-"`
}

func (e *Election) BeforeCreate(tx *gorm.DB) error {
	if e.ID == uuid.Nil {
		e.ID = uuid.New()
	}
	return nil
}

func (Election) TableName() string { return "soc_mitra_elections" }

// ElectionPosition represents a position being contested in an election.
type ElectionPosition struct {
	ID            uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	ElectionID    uuid.UUID `gorm:"type:uuid;not null;index" json:"electionId"`
	Title         string    `gorm:"type:varchar(100);not null" json:"title"`
	TitleMr       string    `gorm:"type:varchar(100)" json:"titleMr,omitempty"`
	MaxCandidates int       `gorm:"default:1" json:"maxCandidates"`
	SortOrder     int       `gorm:"default:0" json:"sortOrder"`
	CreatedAt     time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (p *ElectionPosition) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (ElectionPosition) TableName() string { return "soc_mitra_election_positions" }

// ElectionCandidate represents a member standing for a position.
type ElectionCandidate struct {
	ID           uuid.UUID       `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	ElectionID   uuid.UUID       `gorm:"type:uuid;not null;index" json:"electionId"`
	PositionID   uuid.UUID       `gorm:"type:uuid;not null;index" json:"positionId"`
	MemberID     uuid.UUID       `gorm:"type:uuid;not null" json:"memberId"`
	MemberName   string          `gorm:"type:varchar(100);not null" json:"memberName"`
	FlatNo       string          `gorm:"type:varchar(20)" json:"flatNo"`
	Manifesto    string          `gorm:"type:text" json:"manifesto,omitempty"`
	Status       CandidateStatus `gorm:"type:varchar(20);not null;default:'NOMINATED'" json:"status"`
	ApprovedByID *uuid.UUID      `gorm:"type:uuid" json:"approvedById,omitempty"`
	CreatedAt    time.Time       `gorm:"autoCreateTime" json:"createdAt"`
}

func (c *ElectionCandidate) BeforeCreate(tx *gorm.DB) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	return nil
}

func (ElectionCandidate) TableName() string { return "soc_mitra_election_candidates" }

// ElectionVote represents a single vote cast by a member for a candidate.
type ElectionVote struct {
	ID          uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	ElectionID  uuid.UUID `gorm:"type:uuid;not null;index" json:"electionId"`
	PositionID  uuid.UUID `gorm:"type:uuid;not null;index" json:"positionId"`
	CandidateID uuid.UUID `gorm:"type:uuid;not null;index" json:"candidateId"`
	VoterID     uuid.UUID `gorm:"type:uuid;not null;index" json:"voterId"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (v *ElectionVote) BeforeCreate(tx *gorm.DB) error {
	if v.ID == uuid.Nil {
		v.ID = uuid.New()
	}
	return nil
}

func (ElectionVote) TableName() string { return "soc_mitra_election_votes" }
