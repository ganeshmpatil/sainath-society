package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type TenantRepository struct {
	db *gorm.DB
}

func NewTenantRepository(db *gorm.DB) *TenantRepository {
	return &TenantRepository{db: db}
}

// Create a tenant onboarding request.
//   - Member: OwnerMemberID is forced to actor (member onboards tenant for own flat)
//   - Admin:  can onboard for any flat
func (r *TenantRepository) Create(actor *ActorContext, t *models.Tenant) error {
	if !actor.IsAdmin() {
		t.OwnerMemberID = actor.MemberID
		if actor.FlatID == nil {
			return ErrForbidden
		}
		t.FlatID = *actor.FlatID
	}
	t.Status = models.TenancyPending
	return r.db.Create(t).Error
}

// ListForActor:
//   - Member: only tenants for own flat (owner_member_id = actor)
//   - Admin:  all
func (r *TenantRepository) ListForActor(actor *ActorContext) ([]models.Tenant, error) {
	q := r.db.Model(&models.Tenant{}).Preload("Flat").Preload("Owner").Order("created_at DESC")
	q = ScopeOwnedOrAdmin(q, actor, "owner_member_id")
	var rows []models.Tenant
	err := q.Find(&rows).Error
	return rows, err
}

func (r *TenantRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Tenant, error) {
	var t models.Tenant
	if err := r.db.Preload("Flat").Preload("Owner").First(&t, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, t.OwnerMemberID); err != nil {
		return nil, err
	}
	return &t, nil
}

// Approve — committee/admin only.
func (r *TenantRepository) Approve(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.Tenant{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"status":         models.TenancyApproved,
			"approved_by_id": actor.MemberID,
		}).Error
}

// RecordMovement logs a physical move-in/move-out event.
func (r *TenantRepository) RecordMovement(actor *ActorContext, m *models.TenantMovement) error {
	t, err := r.GetByID(actor, m.TenantID)
	if err != nil {
		return err
	}
	m.FlatID = t.FlatID
	return r.db.Create(m).Error
}

// ListMovements returns the movement log visible to actor (scoped via tenant owner).
func (r *TenantRepository) ListMovements(actor *ActorContext, tenantID uuid.UUID) ([]models.TenantMovement, error) {
	if _, err := r.GetByID(actor, tenantID); err != nil {
		return nil, err
	}
	var rows []models.TenantMovement
	err := r.db.Where("tenant_id = ?", tenantID).Order("scheduled_at DESC").Find(&rows).Error
	return rows, err
}
