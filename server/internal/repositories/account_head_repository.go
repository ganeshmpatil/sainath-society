package repositories

import (
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type AccountHeadRepository struct {
	db *gorm.DB
}

func NewAccountHeadRepository(db *gorm.DB) *AccountHeadRepository {
	return &AccountHeadRepository{db: db}
}

// ListAll returns all account heads ordered by type then code. Admin-only.
func (r *AccountHeadRepository) ListAll(actor *ActorContext) ([]models.AccountHead, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var rows []models.AccountHead
	err := r.db.Where("is_active = ?", true).
		Order("type ASC, code ASC").
		Find(&rows).Error
	return rows, err
}

// ListTree returns top-level accounts (no parent) with nested children. Admin-only.
func (r *AccountHeadRepository) ListTree(actor *ActorContext) ([]models.AccountHead, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var roots []models.AccountHead
	err := r.db.Where("parent_id IS NULL AND is_active = ?", true).
		Preload("Children", "is_active = ?", true).
		Order("type ASC, code ASC").
		Find(&roots).Error
	if err != nil {
		return nil, err
	}
	// Load second level children
	for i := range roots {
		for j := range roots[i].Children {
			r.db.Where("is_active = ?", true).
				Order("code ASC").
				Find(&roots[i].Children[j].Children, "parent_id = ?", roots[i].Children[j].ID)
		}
	}
	return roots, nil
}

// ListByType returns all active accounts of a given type.
func (r *AccountHeadRepository) ListByType(actor *ActorContext, accountType models.AccountType) ([]models.AccountHead, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var rows []models.AccountHead
	err := r.db.Where("type = ? AND is_active = ?", accountType, true).
		Order("code ASC").
		Find(&rows).Error
	return rows, err
}

// GetByID returns a single account head.
func (r *AccountHeadRepository) GetByID(id uuid.UUID) (*models.AccountHead, error) {
	var ah models.AccountHead
	err := r.db.Preload("Children", "is_active = ?", true).
		First(&ah, "id = ?", id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &ah, nil
}

// GetByCode returns an account head by its unique code.
func (r *AccountHeadRepository) GetByCode(code string) (*models.AccountHead, error) {
	var ah models.AccountHead
	err := r.db.First(&ah, "code = ? AND is_active = ?", code, true).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &ah, nil
}

// Create inserts a new account head. Admin-only.
func (r *AccountHeadRepository) Create(actor *ActorContext, ah *models.AccountHead) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	ah.CreatedByID = &actor.MemberID
	return r.db.Create(ah).Error
}

// Update modifies an account head. System accounts have limited editable fields.
func (r *AccountHeadRepository) Update(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	// Check if system account — only allow name/nameMr updates
	var ah models.AccountHead
	if err := r.db.First(&ah, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrNotFound
		}
		return err
	}
	if ah.IsSystem {
		allowed := map[string]interface{}{}
		if v, ok := updates["name"]; ok {
			allowed["name"] = v
		}
		if v, ok := updates["name_mr"]; ok {
			allowed["name_mr"] = v
		}
		updates = allowed
	}
	return r.db.Model(&models.AccountHead{}).Where("id = ?", id).Updates(updates).Error
}

// Delete soft-deletes by setting is_active = false. Cannot delete system accounts.
func (r *AccountHeadRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	var ah models.AccountHead
	if err := r.db.First(&ah, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrNotFound
		}
		return err
	}
	if ah.IsSystem {
		return ErrForbidden
	}
	return r.db.Model(&models.AccountHead{}).Where("id = ?", id).Update("is_active", false).Error
}

// ListLeafAccounts returns non-group active accounts (for use in journal entries).
func (r *AccountHeadRepository) ListLeafAccounts(actor *ActorContext) ([]models.AccountHead, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var rows []models.AccountHead
	err := r.db.Where("is_group = ? AND is_active = ?", false, true).
		Order("type ASC, code ASC").
		Find(&rows).Error
	return rows, err
}
