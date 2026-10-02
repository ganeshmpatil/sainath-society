package models

import (
	"crypto/rand"
	"encoding/hex"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ─── Enums ────────────────────────────────────────────────────

type PatrolShift string

const (
	ShiftMorning   PatrolShift = "MORNING"
	ShiftAfternoon PatrolShift = "AFTERNOON"
	ShiftNight     PatrolShift = "NIGHT"
)

type PatrolRoundStatus string

const (
	RoundInProgress PatrolRoundStatus = "IN_PROGRESS"
	RoundCompleted  PatrolRoundStatus = "COMPLETED"
	RoundMissed     PatrolRoundStatus = "MISSED"
)

type IncidentType string

const (
	IncidentSecurity    IncidentType = "SECURITY"
	IncidentMaintenance IncidentType = "MAINTENANCE"
	IncidentSafety      IncidentType = "SAFETY"
	IncidentNoise       IncidentType = "NOISE"
	IncidentTrespass    IncidentType = "TRESPASS"
	IncidentOther       IncidentType = "OTHER"
)

type IncidentSeverity string

const (
	SeverityLow      IncidentSeverity = "LOW"
	SeverityMedium   IncidentSeverity = "MEDIUM"
	SeverityHigh     IncidentSeverity = "HIGH"
	SeverityCritical IncidentSeverity = "CRITICAL"
)

type IncidentStatus string

const (
	IncidentReported     IncidentStatus = "REPORTED"
	IncidentInvestigating IncidentStatus = "INVESTIGATING"
	IncidentResolved     IncidentStatus = "RESOLVED"
	IncidentClosed       IncidentStatus = "CLOSED"
)

// ─── Models ───────────────────────────────────────────────────

// PatrolCheckpoint is a named scanning point within the society premises.
type PatrolCheckpoint struct {
	TenantScope
	ID          uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name        string    `gorm:"type:varchar(100);not null" json:"name"`
	NameMr      string    `gorm:"type:varchar(100)" json:"nameMr,omitempty"`
	Location    string    `gorm:"type:varchar(200)" json:"location,omitempty"`
	LocationMr  string    `gorm:"type:varchar(200)" json:"locationMr,omitempty"`
	QRCode      string    `gorm:"type:varchar(64);uniqueIndex;not null" json:"qrCode"`
	IsActive    bool      `gorm:"default:true" json:"isActive"`
	SortOrder   int       `gorm:"default:0" json:"sortOrder"`
	CreatedByID uuid.UUID `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (p *PatrolCheckpoint) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	if p.QRCode == "" {
		b := make([]byte, 16)
		if _, err := rand.Read(b); err == nil {
			p.QRCode = "CHK-" + hex.EncodeToString(b)
		}
	}
	return nil
}

func (PatrolCheckpoint) TableName() string { return "soc_mitra_patrol_checkpoints" }

// PatrolRound represents one guard patrol shift.
type PatrolRound struct {
	TenantScope
	ID                uuid.UUID         `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	GuardName         string            `gorm:"type:varchar(100);not null" json:"guardName"`
	ShiftType         PatrolShift       `gorm:"type:varchar(20);not null;default:'MORNING'" json:"shiftType"`
	StartTime         time.Time         `gorm:"not null" json:"startTime"`
	EndTime           *time.Time        `json:"endTime,omitempty"`
	Status            PatrolRoundStatus `gorm:"type:varchar(20);not null;default:'IN_PROGRESS'" json:"status"`
	TotalCheckpoints  int               `gorm:"default:0" json:"totalCheckpoints"`
	ScannedCheckpoints int              `gorm:"default:0" json:"scannedCheckpoints"`
	Notes             string            `gorm:"type:text" json:"notes,omitempty"`
	CreatedByID       uuid.UUID         `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt         time.Time         `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt         time.Time         `gorm:"autoUpdateTime" json:"updatedAt"`

	Scans []PatrolScan `gorm:"foreignKey:RoundID" json:"scans,omitempty"`
}

func (p *PatrolRound) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (PatrolRound) TableName() string { return "soc_mitra_patrol_rounds" }

// PatrolScan records when a guard scans a checkpoint during a round.
type PatrolScan struct {
	TenantScope
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	RoundID      uuid.UUID `gorm:"type:uuid;not null;index" json:"roundId"`
	CheckpointID uuid.UUID `gorm:"type:uuid;not null;index" json:"checkpointId"`
	ScannedAt    time.Time `gorm:"not null" json:"scannedAt"`
	Lat          float64   `gorm:"type:decimal(10,7)" json:"lat,omitempty"`
	Lng          float64   `gorm:"type:decimal(10,7)" json:"lng,omitempty"`
	Notes        string    `gorm:"type:text" json:"notes,omitempty"`

	Round      *PatrolRound      `gorm:"foreignKey:RoundID" json:"round,omitempty"`
	Checkpoint *PatrolCheckpoint `gorm:"foreignKey:CheckpointID" json:"checkpoint,omitempty"`
}

func (p *PatrolScan) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (PatrolScan) TableName() string { return "soc_mitra_patrol_scans" }

// PatrolIncident records a security or maintenance incident.
type PatrolIncident struct {
	TenantScope
	ID             uuid.UUID        `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Title          string           `gorm:"type:varchar(200);not null" json:"title"`
	TitleMr        string           `gorm:"type:varchar(200)" json:"titleMr,omitempty"`
	Description    string           `gorm:"type:text" json:"description,omitempty"`
	IncidentType   IncidentType     `gorm:"type:varchar(20);not null;default:'OTHER'" json:"incidentType"`
	Severity       IncidentSeverity `gorm:"type:varchar(20);not null;default:'LOW'" json:"severity"`
	Status         IncidentStatus   `gorm:"type:varchar(20);not null;default:'REPORTED'" json:"status"`
	Location       string           `gorm:"type:varchar(200)" json:"location,omitempty"`
	ReportedByID   uuid.UUID        `gorm:"type:uuid;not null" json:"reportedById"`
	ReportedByName string           `gorm:"type:varchar(100)" json:"reportedByName,omitempty"`
	ResolvedByID   *uuid.UUID       `gorm:"type:uuid" json:"resolvedById,omitempty"`
	ResolvedAt     *time.Time       `json:"resolvedAt,omitempty"`
	Notes          string           `gorm:"type:text" json:"notes,omitempty"`
	CreatedAt      time.Time        `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt      time.Time        `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (p *PatrolIncident) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (PatrolIncident) TableName() string { return "soc_mitra_patrol_incidents" }
