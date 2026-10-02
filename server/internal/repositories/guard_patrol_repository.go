package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type GuardPatrolRepository struct {
	db *gorm.DB
}

func NewGuardPatrolRepository(db *gorm.DB) *GuardPatrolRepository {
	return &GuardPatrolRepository{db: db}
}

// ─── Checkpoints ──────────────────────────────────────────────

func (r *GuardPatrolRepository) ListCheckpoints() ([]models.PatrolCheckpoint, error) {
	var checkpoints []models.PatrolCheckpoint
	err := r.db.Order("sort_order ASC, name ASC").Find(&checkpoints).Error
	return checkpoints, err
}

func (r *GuardPatrolRepository) CreateCheckpoint(actor *ActorContext, cp *models.PatrolCheckpoint) error {
	cp.CreatedByID = actor.UserID
	return r.db.Create(cp).Error
}

func (r *GuardPatrolRepository) UpdateCheckpoint(id uuid.UUID, updates map[string]interface{}) error {
	return r.db.Model(&models.PatrolCheckpoint{}).Where("id = ?", id).Updates(updates).Error
}

func (r *GuardPatrolRepository) DeleteCheckpoint(id uuid.UUID) error {
	return r.db.Delete(&models.PatrolCheckpoint{}, "id = ?", id).Error
}

// ─── Rounds ───────────────────────────────────────────────────

func (r *GuardPatrolRepository) ListRounds(date *time.Time, status string) ([]models.PatrolRound, error) {
	q := r.db.Order("created_at DESC").Limit(100)
	if date != nil {
		start := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
		end := start.Add(24 * time.Hour)
		q = q.Where("start_time >= ? AND start_time < ?", start, end)
	}
	if status != "" {
		q = q.Where("status = ?", status)
	}
	var rounds []models.PatrolRound
	err := q.Find(&rounds).Error
	return rounds, err
}

func (r *GuardPatrolRepository) GetRoundByID(id uuid.UUID) (*models.PatrolRound, error) {
	var round models.PatrolRound
	err := r.db.Preload("Scans").Preload("Scans.Checkpoint").First(&round, "id = ?", id).Error
	return &round, err
}

func (r *GuardPatrolRepository) StartRound(actor *ActorContext, round *models.PatrolRound) error {
	round.CreatedByID = actor.UserID
	if round.StartTime.IsZero() {
		round.StartTime = time.Now()
	}
	round.Status = models.RoundInProgress

	// Set total checkpoints count from active checkpoints
	var count int64
	r.db.Model(&models.PatrolCheckpoint{}).Where("is_active = ?", true).Count(&count)
	round.TotalCheckpoints = int(count)

	return r.db.Create(round).Error
}

func (r *GuardPatrolRepository) CompleteRound(id uuid.UUID, notes string) error {
	now := time.Now()
	updates := map[string]interface{}{
		"status":   models.RoundCompleted,
		"end_time": now,
	}
	if notes != "" {
		updates["notes"] = notes
	}
	return r.db.Model(&models.PatrolRound{}).Where("id = ?", id).Updates(updates).Error
}

// ─── Scans ────────────────────────────────────────────────────

func (r *GuardPatrolRepository) AddScan(scan *models.PatrolScan) error {
	if scan.ScannedAt.IsZero() {
		scan.ScannedAt = time.Now()
	}
	if err := r.db.Create(scan).Error; err != nil {
		return err
	}
	// Increment scanned_checkpoints on the round
	return r.db.Model(&models.PatrolRound{}).Where("id = ?", scan.RoundID).
		UpdateColumn("scanned_checkpoints", gorm.Expr("scanned_checkpoints + 1")).Error
}

// ─── Incidents ────────────────────────────────────────────────

func (r *GuardPatrolRepository) ListIncidents(incidentType, severity, status string) ([]models.PatrolIncident, error) {
	q := r.db.Order("created_at DESC").Limit(100)
	if incidentType != "" {
		q = q.Where("incident_type = ?", incidentType)
	}
	if severity != "" {
		q = q.Where("severity = ?", severity)
	}
	if status != "" {
		q = q.Where("status = ?", status)
	}
	var incidents []models.PatrolIncident
	err := q.Find(&incidents).Error
	return incidents, err
}

func (r *GuardPatrolRepository) GetIncidentByID(id uuid.UUID) (*models.PatrolIncident, error) {
	var incident models.PatrolIncident
	err := r.db.First(&incident, "id = ?", id).Error
	return &incident, err
}

func (r *GuardPatrolRepository) CreateIncident(actor *ActorContext, incident *models.PatrolIncident) error {
	incident.ReportedByID = actor.UserID
	return r.db.Create(incident).Error
}

func (r *GuardPatrolRepository) UpdateIncidentStatus(actor *ActorContext, id uuid.UUID, status models.IncidentStatus, notes string) error {
	updates := map[string]interface{}{
		"status": status,
	}
	if notes != "" {
		updates["notes"] = notes
	}
	if status == models.IncidentResolved || status == models.IncidentClosed {
		now := time.Now()
		updates["resolved_by_id"] = actor.UserID
		updates["resolved_at"] = now
	}
	return r.db.Model(&models.PatrolIncident{}).Where("id = ?", id).Updates(updates).Error
}
