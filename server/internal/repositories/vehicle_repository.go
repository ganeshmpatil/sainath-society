package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type VehicleRepository struct {
	db *gorm.DB
}

func NewVehicleRepository(db *gorm.DB) *VehicleRepository {
	return &VehicleRepository{db: db}
}

// Register a new vehicle. Non-admins are forced to own the row. Admins may
// pass OwnerMemberID explicitly; otherwise the actor is used as the default.
func (r *VehicleRepository) Create(actor *ActorContext, v *models.Vehicle) error {
	if !actor.IsAdmin() {
		v.OwnerMemberID = actor.MemberID
		v.FlatID = actor.FlatID
	}
	if v.OwnerMemberID == (uuid.UUID{}) {
		v.OwnerMemberID = actor.MemberID
	}
	if v.FlatID == nil && actor.FlatID != nil {
		v.FlatID = actor.FlatID
	}
	return r.db.Create(v).Error
}

// List returns vehicles visible to the actor.
func (r *VehicleRepository) List(actor *ActorContext) ([]models.Vehicle, error) {
	q := r.db.Model(&models.Vehicle{}).Preload("Owner").Preload("Flat").Order("created_at DESC")
	q = ScopeOwnedOrAdmin(q, actor, "owner_member_id")
	var rows []models.Vehicle
	err := q.Find(&rows).Error
	return rows, err
}

// GetByID returns a single vehicle, ACL-enforced.
func (r *VehicleRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Vehicle, error) {
	var v models.Vehicle
	if err := r.db.Preload("Owner").Preload("Flat").First(&v, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, v.OwnerMemberID); err != nil {
		return nil, err
	}
	return &v, nil
}

// Update allows owner or admin to edit. Cannot change owner unless admin.
func (r *VehicleRepository) Update(actor *ActorContext, id uuid.UUID, patch map[string]interface{}) error {
	v, err := r.GetByID(actor, id)
	if err != nil {
		return err
	}
	if !actor.IsAdmin() {
		delete(patch, "owner_member_id")
		delete(patch, "flat_id")
	}
	return r.db.Model(v).Updates(patch).Error
}

// Delete soft-deletes (IsActive = false) after ACL check.
func (r *VehicleRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	v, err := r.GetByID(actor, id)
	if err != nil {
		return err
	}
	return r.db.Model(v).Update("is_active", false).Error
}
