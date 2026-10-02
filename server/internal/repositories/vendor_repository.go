package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type VendorRepository struct {
	db *gorm.DB
}

func NewVendorRepository(db *gorm.DB) *VendorRepository {
	return &VendorRepository{db: db}
}

// List returns all active vendors. Admin-only.
func (r *VendorRepository) List(actor *ActorContext) ([]models.Vendor, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var rows []models.Vendor
	err := r.db.Where("is_active = ?", true).
		Order("name ASC").
		Find(&rows).Error
	return rows, err
}

// GetByID returns a single vendor.
func (r *VendorRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Vendor, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var v models.Vendor
	err := r.db.First(&v, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &v, nil
}

// Create adds a new vendor. Admin-only.
func (r *VendorRepository) Create(actor *ActorContext, v *models.Vendor) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	v.CreatedByID = &actor.UserID
	return r.db.Create(v).Error
}

// Update modifies an existing vendor. Admin-only.
func (r *VendorRepository) Update(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.Vendor{}).Where("id = ?", id).Updates(updates).Error
}

// Delete soft-deactivates a vendor. Admin-only.
func (r *VendorRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.Vendor{}).Where("id = ?", id).Update("is_active", false).Error
}
