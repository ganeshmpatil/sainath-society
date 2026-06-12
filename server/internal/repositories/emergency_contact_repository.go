package repositories

import (
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type EmergencyContactRepository struct {
	db *gorm.DB
}

func NewEmergencyContactRepository(db *gorm.DB) *EmergencyContactRepository {
	return &EmergencyContactRepository{db: db}
}

// List returns all active emergency contacts ordered by category then sort_order.
func (r *EmergencyContactRepository) List() ([]models.EmergencyContact, error) {
	var rows []models.EmergencyContact
	err := r.db.Where("is_active = ?", true).
		Order("category, sort_order, name").
		Find(&rows).Error
	return rows, err
}

// Create adds a new emergency contact. Admin-only.
func (r *EmergencyContactRepository) Create(actor *ActorContext, ec *models.EmergencyContact) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	ec.AddedByID = &actor.MemberID
	return r.db.Create(ec).Error
}

// Update modifies an existing emergency contact. Admin-only.
func (r *EmergencyContactRepository) Update(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.EmergencyContact{}).Where("id = ?", id).Updates(updates)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// Delete soft-deletes (deactivates) an emergency contact. Admin-only.
func (r *EmergencyContactRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	var ec models.EmergencyContact
	if err := r.db.First(&ec, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrNotFound
		}
		return err
	}
	return r.db.Model(&ec).Update("is_active", false).Error
}

// ListCommitteeMembers returns admin/designated members as committee contacts.
func (r *EmergencyContactRepository) ListCommitteeMembers() ([]models.Member, error) {
	var members []models.Member
	err := r.db.Where("is_active = ? AND (role = ? OR designation != '')", true, models.RoleAdmin).
		Preload("Flat").
		Order("role DESC, designation, name").
		Find(&members).Error
	return members, err
}
