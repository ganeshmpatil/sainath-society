package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type ByLawRepository struct {
	db *gorm.DB
}

func NewByLawRepository(db *gorm.DB) *ByLawRepository {
	return &ByLawRepository{db: db}
}

// List returns all active bylaws — visible to every authenticated member.
func (r *ByLawRepository) List(actor *ActorContext) ([]models.ByLaw, error) {
	q := r.db.Model(&models.ByLaw{}).Order("section ASC")
	if !actor.IsAdmin() {
		q = q.Where("is_active = ?", true)
	}
	var rows []models.ByLaw
	err := q.Find(&rows).Error
	return rows, err
}

func (r *ByLawRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.ByLaw, error) {
	var b models.ByLaw
	if err := r.db.First(&b, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &b, nil
}

// Create — admin only.
func (r *ByLawRepository) Create(actor *ActorContext, b *models.ByLaw) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	b.CreatedByID = actor.MemberID
	return r.db.Create(b).Error
}

// Amend logs the change in the audit trail and updates the bylaw.
func (r *ByLawRepository) Amend(actor *ActorContext, id uuid.UUID, newContent, reason string) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		var existing models.ByLaw
		if err := tx.First(&existing, "id = ?", id).Error; err != nil {
			return err
		}
		log := &models.ByLawAmendmentLog{
			ByLawID:     id,
			OldContent:  existing.Content,
			NewContent:  newContent,
			ChangedByID: actor.MemberID,
			Reason:      reason,
		}
		if err := tx.Create(log).Error; err != nil {
			return err
		}
		return tx.Model(&existing).Updates(map[string]interface{}{
			"content": newContent,
			"version": existing.Version + 1,
		}).Error
	})
}
