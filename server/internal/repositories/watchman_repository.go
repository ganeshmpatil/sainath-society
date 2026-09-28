package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type WatchmanRepository struct {
	db *gorm.DB
}

func NewWatchmanRepository(db *gorm.DB) *WatchmanRepository {
	return &WatchmanRepository{db: db}
}

// Create adds a new watchman. Admin only.
func (r *WatchmanRepository) Create(actor *ActorContext, w *models.Watchman) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Create(w).Error
}

// List returns all active watchmen. Visible to everyone.
func (r *WatchmanRepository) List() ([]models.Watchman, error) {
	var rows []models.Watchman
	err := r.db.Where("is_active = ?", true).Order("duty_start_time ASC").Find(&rows).Error
	return rows, err
}

// GetByID returns a single watchman by ID.
func (r *WatchmanRepository) GetByID(id uuid.UUID) (*models.Watchman, error) {
	var w models.Watchman
	if err := r.db.First(&w, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &w, nil
}

// Update modifies a watchman. Admin only.
func (r *WatchmanRepository) Update(actor *ActorContext, id uuid.UUID, patch map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	w, err := r.GetByID(id)
	if err != nil {
		return err
	}
	return r.db.Model(w).Updates(patch).Error
}

// Delete soft-deletes a watchman. Admin only.
func (r *WatchmanRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	w, err := r.GetByID(id)
	if err != nil {
		return err
	}
	return r.db.Model(w).Update("is_active", false).Error
}
