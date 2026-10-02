package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type FlatChargeOverrideRepository struct {
	db *gorm.DB
}

func NewFlatChargeOverrideRepository(db *gorm.DB) *FlatChargeOverrideRepository {
	return &FlatChargeOverrideRepository{db: db}
}

// ListForFlat returns all overrides for a given flat.
func (r *FlatChargeOverrideRepository) ListForFlat(actor *ActorContext, flatID uuid.UUID) ([]models.FlatChargeOverride, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var rows []models.FlatChargeOverride
	err := r.db.Where("flat_id = ?", flatID).
		Preload("ChargeHead").
		Find(&rows).Error
	return rows, err
}

// ListAll returns all overrides with flat and charge head info.
func (r *FlatChargeOverrideRepository) ListAll(actor *ActorContext) ([]models.FlatChargeOverride, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var rows []models.FlatChargeOverride
	err := r.db.Preload("Flat").Preload("ChargeHead").
		Order("flat_id, charge_head_id").
		Find(&rows).Error
	return rows, err
}

// Upsert creates or updates an override for a flat+charge head combination.
func (r *FlatChargeOverrideRepository) Upsert(actor *ActorContext, o *models.FlatChargeOverride) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	o.CreatedByID = actor.MemberID

	// Check if override already exists
	var existing models.FlatChargeOverride
	err := r.db.Where("flat_id = ? AND charge_head_id = ?", o.FlatID, o.ChargeHeadID).First(&existing).Error
	if err == nil {
		// Update existing
		return r.db.Model(&existing).Updates(map[string]interface{}{
			"rate":    o.Rate,
			"exempt":  o.Exempt,
			"reason":  o.Reason,
		}).Error
	}
	return r.db.Create(o).Error
}

// Delete removes an override.
func (r *FlatChargeOverrideRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Delete(&models.FlatChargeOverride{}, "id = ?", id)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}
