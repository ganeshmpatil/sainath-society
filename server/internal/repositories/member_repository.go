package repositories

import (
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

// MemberRepository handles CRUD for the Member registry. Note this is
// distinct from the legacy `repository.UserRepository` (login credentials):
// this repository operates on the pre-seeded society member roster.
type MemberRepository struct {
	db *gorm.DB
}

func NewMemberRepository(db *gorm.DB) *MemberRepository {
	return &MemberRepository{db: db}
}

// List returns residents.
//   Admin: every member
//   Member: every member (society directory is visible to all residents)
// Sensitive fields (mobile) can be masked at the handler layer if required.
func (r *MemberRepository) List(actor *ActorContext, role *models.Role, onlyActive bool) ([]models.Member, error) {
	q := r.db.Preload("Flat").Preload("Flat.Wing").Order("name ASC")
	if role != nil {
		q = q.Where("role = ?", *role)
	}
	if onlyActive {
		q = q.Where("is_active = ?", true)
	}
	var rows []models.Member
	err := q.Find(&rows).Error
	return rows, err
}

func (r *MemberRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Member, error) {
	var m models.Member
	if err := r.db.Preload("Flat").Preload("Flat.Wing").First(&m, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &m, nil
}

// Create a new member (pre-seed) — admin only. Triggers no login.
func (r *MemberRepository) Create(actor *ActorContext, m *models.Member) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	by := actor.MemberID
	m.AddedBy = &by
	m.IsActive = true
	return r.db.Create(m).Error
}

// Update lets the owner update their own profile fields; admins update anyone.
func (r *MemberRepository) Update(actor *ActorContext, id uuid.UUID, patch map[string]interface{}) error {
	if !actor.IsAdmin() && actor.MemberID != id {
		return ErrForbidden
	}
	if !actor.IsAdmin() {
		// Members can't change role/designation/flat assignments.
		delete(patch, "role")
		delete(patch, "designation")
		delete(patch, "flat_id")
		delete(patch, "is_active")
	}
	return r.db.Model(&models.Member{}).Where("id = ?", id).Updates(patch).Error
}

// Deactivate — admin only.
func (r *MemberRepository) Deactivate(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.Member{}).Where("id = ?", id).
		Update("is_active", false).Error
}
