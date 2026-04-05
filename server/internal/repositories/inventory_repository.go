package repositories

import (
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type InventoryRepository struct {
	db *gorm.DB
}

func NewInventoryRepository(db *gorm.DB) *InventoryRepository {
	return &InventoryRepository{db: db}
}

// Create an inventory item — admin only.
func (r *InventoryRepository) Create(actor *ActorContext, item *models.InventoryItem) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	item.AddedByID = actor.MemberID
	if item.TotalValue == 0 && item.UnitPrice > 0 {
		item.TotalValue = item.UnitPrice * float64(item.Quantity)
	}
	return r.db.Create(item).Error
}

// List returns all items. Members see read-only; admins mutate.
func (r *InventoryRepository) List(actor *ActorContext, category string) ([]models.InventoryItem, error) {
	q := r.db.Order("name ASC")
	if category != "" {
		q = q.Where("category = ?", category)
	}
	var rows []models.InventoryItem
	err := q.Find(&rows).Error
	return rows, err
}

func (r *InventoryRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.InventoryItem, error) {
	var item models.InventoryItem
	if err := r.db.First(&item, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &item, nil
}

func (r *InventoryRepository) Update(actor *ActorContext, id uuid.UUID, patch map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.InventoryItem{}).Where("id = ?", id).Updates(patch).Error
}

func (r *InventoryRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Delete(&models.InventoryItem{}, "id = ?", id).Error
}
