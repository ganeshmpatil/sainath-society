package repositories

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

var ErrSlotAlreadyAllocated = errors.New("parking slot is already allocated")

type ParkingRepository struct {
	db *gorm.DB
}

func NewParkingRepository(db *gorm.DB) *ParkingRepository {
	return &ParkingRepository{db: db}
}

// List all parking slots (visible to all members — non-sensitive data).
func (r *ParkingRepository) List(actor *ActorContext) ([]models.ParkingSlot, error) {
	var rows []models.ParkingSlot
	err := r.db.Preload("Flat").Where("is_active = ?", true).
		Order("slot_number ASC").Find(&rows).Error
	return rows, err
}

// Create a new parking slot — admin only.
func (r *ParkingRepository) Create(actor *ActorContext, slot *models.ParkingSlot) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	slot.IsActive = true
	return r.db.Create(slot).Error
}

// Allocate assigns an unassigned slot to a flat/member — admin only.
func (r *ParkingRepository) Allocate(actor *ActorContext, slotID, flatID, memberID uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		var slot models.ParkingSlot
		if err := tx.First(&slot, "id = ?", slotID).Error; err != nil {
			return ErrNotFound
		}
		if slot.AllocatedToFlatID != nil {
			return ErrSlotAlreadyAllocated
		}
		now := time.Now()
		return tx.Model(&slot).Updates(map[string]interface{}{
			"allocated_to_flat_id":   flatID,
			"allocated_to_member_id": memberID,
			"allocated_at":           now,
		}).Error
	})
}

// Release frees a slot — admin only.
func (r *ParkingRepository) Release(actor *ActorContext, slotID uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.ParkingSlot{}).Where("id = ?", slotID).
		Updates(map[string]interface{}{
			"allocated_to_flat_id":   nil,
			"allocated_to_member_id": nil,
			"allocated_at":           nil,
		}).Error
}

func (r *ParkingRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.ParkingSlot, error) {
	var slot models.ParkingSlot
	if err := r.db.Preload("Flat").First(&slot, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &slot, nil
}
