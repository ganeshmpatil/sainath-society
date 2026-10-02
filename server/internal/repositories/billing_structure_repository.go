package repositories

import (
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type BillingStructureRepository struct {
	db *gorm.DB
}

func NewBillingStructureRepository(db *gorm.DB) *BillingStructureRepository {
	return &BillingStructureRepository{db: db}
}

// ─── Billing Structure CRUD ─────────────────────────────────────

// GetActive returns the currently active billing structure with charge heads.
func (r *BillingStructureRepository) GetActive() (*models.BillingStructure, error) {
	var bs models.BillingStructure
	err := r.db.Where("is_active = ?", true).
		Preload("ChargeHeads", func(db *gorm.DB) *gorm.DB {
			return db.Where("is_active = ?", true).Order("sort_order ASC")
		}).
		First(&bs).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &bs, nil
}

// GetByID returns a billing structure by ID with charge heads.
func (r *BillingStructureRepository) GetByID(id uuid.UUID) (*models.BillingStructure, error) {
	var bs models.BillingStructure
	err := r.db.Preload("ChargeHeads", func(db *gorm.DB) *gorm.DB {
		return db.Order("sort_order ASC")
	}).First(&bs, "id = ?", id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &bs, nil
}

// ListAll returns all billing structures (admin view).
func (r *BillingStructureRepository) ListAll() ([]models.BillingStructure, error) {
	var rows []models.BillingStructure
	err := r.db.Preload("ChargeHeads", func(db *gorm.DB) *gorm.DB {
		return db.Order("sort_order ASC")
	}).Order("created_at DESC").Find(&rows).Error
	return rows, err
}

// Create inserts a new billing structure. If isActive, deactivates others first.
func (r *BillingStructureRepository) Create(actor *ActorContext, bs *models.BillingStructure) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		if bs.IsActive {
			tx.Model(&models.BillingStructure{}).Where("is_active = ?", true).
				Update("is_active", false)
		}
		bs.CreatedByID = actor.MemberID
		return tx.Create(bs).Error
	})
}

// Update modifies a billing structure.
func (r *BillingStructureRepository) Update(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		if isActive, ok := updates["is_active"]; ok && isActive == true {
			tx.Model(&models.BillingStructure{}).Where("is_active = ? AND id != ?", true, id).
				Update("is_active", false)
		}
		return tx.Model(&models.BillingStructure{}).Where("id = ?", id).Updates(updates).Error
	})
}

// ─── Charge Head CRUD ───────────────────────────────────────────

// AddChargeHead adds a charge head to a billing structure.
func (r *BillingStructureRepository) AddChargeHead(actor *ActorContext, ch *models.ChargeHead) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Create(ch).Error
}

// UpdateChargeHead modifies a charge head.
func (r *BillingStructureRepository) UpdateChargeHead(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.ChargeHead{}).Where("id = ?", id).Updates(updates).Error
}

// DeleteChargeHead soft-deletes by setting is_active = false.
func (r *BillingStructureRepository) DeleteChargeHead(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.ChargeHead{}).Where("id = ?", id).Update("is_active", false).Error
}

// ─── Line Items ─────────────────────────────────────────────────

// GetLineItems returns breakdown for a bill.
func (r *BillingStructureRepository) GetLineItems(billID uuid.UUID) ([]models.BillLineItem, error) {
	var items []models.BillLineItem
	err := r.db.Where("bill_id = ?", billID).Order("created_at ASC").Find(&items).Error
	return items, err
}
