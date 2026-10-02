package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type VisitorRepository struct {
	db *gorm.DB
}

func NewVisitorRepository(db *gorm.DB) *VisitorRepository {
	return &VisitorRepository{db: db}
}

// ─── Visitor Entry Log ─────────────────────────────────────────

func (r *VisitorRepository) List(actor *ActorContext, flatID *uuid.UUID, status string, date *time.Time) ([]models.Visitor, error) {
	q := r.db.Order("created_at DESC")

	// Non-admin can only see their flat's visitors
	if !actor.IsAdmin() {
		q = q.Where("flat_id = ?", actor.FlatID)
	} else if flatID != nil {
		q = q.Where("flat_id = ?", *flatID)
	}

	if status != "" {
		q = q.Where("status = ?", status)
	}

	if date != nil {
		start := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
		end := start.Add(24 * time.Hour)
		q = q.Where("created_at >= ? AND created_at < ?", start, end)
	}

	q = q.Limit(100)

	var visitors []models.Visitor
	err := q.Find(&visitors).Error
	return visitors, err
}

func (r *VisitorRepository) GetByID(id uuid.UUID) (*models.Visitor, error) {
	var v models.Visitor
	err := r.db.First(&v, "id = ?", id).Error
	return &v, err
}

func (r *VisitorRepository) Create(actor *ActorContext, v *models.Visitor) error {
	v.CreatedByID = actor.UserID
	return r.db.Create(v).Error
}

func (r *VisitorRepository) Approve(actor *ActorContext, id uuid.UUID) error {
	now := time.Now()
	return r.db.Model(&models.Visitor{}).Where("id = ?", id).Updates(map[string]interface{}{
		"status":      models.VisitorApproved,
		"approved_by": actor.UserID,
		"entry_time":  now,
	}).Error
}

func (r *VisitorRepository) CheckIn(id uuid.UUID) error {
	now := time.Now()
	return r.db.Model(&models.Visitor{}).Where("id = ?", id).Updates(map[string]interface{}{
		"status":     models.VisitorCheckedIn,
		"entry_time": now,
	}).Error
}

func (r *VisitorRepository) CheckOut(id uuid.UUID) error {
	now := time.Now()
	return r.db.Model(&models.Visitor{}).Where("id = ?", id).Updates(map[string]interface{}{
		"status":    models.VisitorCheckedOut,
		"exit_time": now,
	}).Error
}

func (r *VisitorRepository) Reject(actor *ActorContext, id uuid.UUID, reason string) error {
	return r.db.Model(&models.Visitor{}).Where("id = ?", id).Updates(map[string]interface{}{
		"status":        models.VisitorRejected,
		"rejected_by":   actor.UserID,
		"reject_reason": reason,
	}).Error
}

func (r *VisitorRepository) TodaySummary() (map[string]int64, error) {
	today := time.Now().Truncate(24 * time.Hour)
	tomorrow := today.Add(24 * time.Hour)

	result := map[string]int64{}
	var total int64
	r.db.Model(&models.Visitor{}).Where("created_at >= ? AND created_at < ?", today, tomorrow).Count(&total)
	result["total"] = total

	var checkedIn int64
	r.db.Model(&models.Visitor{}).Where("created_at >= ? AND created_at < ? AND status = ?", today, tomorrow, models.VisitorCheckedIn).Count(&checkedIn)
	result["checkedIn"] = checkedIn

	var pending int64
	r.db.Model(&models.Visitor{}).Where("created_at >= ? AND created_at < ? AND status = ?", today, tomorrow, models.VisitorPending).Count(&pending)
	result["pending"] = pending

	var checkedOut int64
	r.db.Model(&models.Visitor{}).Where("created_at >= ? AND created_at < ? AND status = ?", today, tomorrow, models.VisitorCheckedOut).Count(&checkedOut)
	result["checkedOut"] = checkedOut

	return result, nil
}

// ─── Frequent / Pre-approved Visitors ──────────────────────────

func (r *VisitorRepository) ListFrequent(actor *ActorContext, flatID *uuid.UUID) ([]models.FrequentVisitor, error) {
	q := r.db.Order("name ASC")
	if !actor.IsAdmin() {
		q = q.Where("flat_id = ?", actor.FlatID)
	} else if flatID != nil {
		q = q.Where("flat_id = ?", *flatID)
	}
	var fv []models.FrequentVisitor
	err := q.Find(&fv).Error
	return fv, err
}

func (r *VisitorRepository) CreateFrequent(actor *ActorContext, fv *models.FrequentVisitor) error {
	fv.CreatedByID = actor.UserID
	return r.db.Create(fv).Error
}

func (r *VisitorRepository) UpdateFrequent(id uuid.UUID, updates map[string]interface{}) error {
	return r.db.Model(&models.FrequentVisitor{}).Where("id = ?", id).Updates(updates).Error
}

func (r *VisitorRepository) DeleteFrequent(id uuid.UUID) error {
	return r.db.Delete(&models.FrequentVisitor{}, "id = ?", id).Error
}

func (r *VisitorRepository) BlacklistFrequent(id uuid.UUID, reason string) error {
	return r.db.Model(&models.FrequentVisitor{}).Where("id = ?", id).Updates(map[string]interface{}{
		"is_blacklisted":   true,
		"blacklist_reason": reason,
		"is_active":        false,
	}).Error
}
