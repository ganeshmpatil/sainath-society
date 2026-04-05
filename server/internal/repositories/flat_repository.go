package repositories

import (
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type FlatRepository struct {
	db *gorm.DB
}

func NewFlatRepository(db *gorm.DB) *FlatRepository {
	return &FlatRepository{db: db}
}

// List returns all flats. Everyone can see the flat registry (non-sensitive).
func (r *FlatRepository) List(actor *ActorContext, wingID *uuid.UUID) ([]models.Flat, error) {
	q := r.db.Preload("Wing").Order("flat_number ASC")
	if wingID != nil {
		q = q.Where("wing_id = ?", *wingID)
	}
	var rows []models.Flat
	err := q.Find(&rows).Error
	return rows, err
}

func (r *FlatRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Flat, error) {
	var f models.Flat
	if err := r.db.Preload("Wing").First(&f, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &f, nil
}

// Create — admin only.
func (r *FlatRepository) Create(actor *ActorContext, f *models.Flat) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Create(f).Error
}

// Update — admin only for all fields; members can only update their own flat
// if needed (currently disallowed).
func (r *FlatRepository) Update(actor *ActorContext, id uuid.UUID, patch map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.Flat{}).Where("id = ?", id).Updates(patch).Error
}

// ListWings returns all wings — used for UI selectors.
func (r *FlatRepository) ListWings() ([]models.Wing, error) {
	var rows []models.Wing
	err := r.db.Order("name ASC").Find(&rows).Error
	return rows, err
}
