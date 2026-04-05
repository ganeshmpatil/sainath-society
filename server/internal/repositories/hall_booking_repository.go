package repositories

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

var ErrSlotUnavailable = errors.New("hall is already booked for the requested slot")

type HallBookingRepository struct {
	db *gorm.DB
}

func NewHallBookingRepository(db *gorm.DB) *HallBookingRepository {
	return &HallBookingRepository{db: db}
}

// Create a booking request. The repo:
//   1. Forces booker = actor for members
//   2. Rejects overlapping APPROVED bookings
func (r *HallBookingRepository) Create(actor *ActorContext, b *models.HallBooking) error {
	if !actor.IsAdmin() {
		b.BookedByMemberID = actor.MemberID
		b.FlatID = actor.FlatID
	}
	if b.BookedByMemberID == (uuid.UUID{}) {
		b.BookedByMemberID = actor.MemberID
	}

	// Overlap check against approved bookings.
	var overlap int64
	r.db.Model(&models.HallBooking{}).
		Where("status = ?", models.HallBookingApproved).
		Where("start_time < ? AND end_time > ?", b.EndTime, b.StartTime).
		Count(&overlap)
	if overlap > 0 {
		return ErrSlotUnavailable
	}

	b.Status = models.HallBookingPending
	return r.db.Create(b).Error
}

// ListForActor returns bookings visible to the actor.
//   Member: only own (booked_by_member_id = actor)
//   Admin:  all
func (r *HallBookingRepository) ListForActor(actor *ActorContext) ([]models.HallBooking, error) {
	q := r.db.Model(&models.HallBooking{}).Preload("BookedBy").Preload("Flat").
		Order("start_time DESC")
	q = ScopeOwnedOrAdmin(q, actor, "booked_by_member_id")
	var rows []models.HallBooking
	err := q.Find(&rows).Error
	return rows, err
}

// CheckAvailability returns true when no APPROVED booking overlaps the given
// window. Used by the availability check endpoint.
func (r *HallBookingRepository) CheckAvailability(start, end time.Time) (bool, error) {
	var count int64
	err := r.db.Model(&models.HallBooking{}).
		Where("status = ?", models.HallBookingApproved).
		Where("start_time < ? AND end_time > ?", end, start).
		Count(&count).Error
	return count == 0, err
}

func (r *HallBookingRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.HallBooking, error) {
	var b models.HallBooking
	if err := r.db.Preload("BookedBy").Preload("Flat").First(&b, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, b.BookedByMemberID); err != nil {
		return nil, err
	}
	return &b, nil
}

// Approve or Reject — admin only.
func (r *HallBookingRepository) Decide(actor *ActorContext, id uuid.UUID, approve bool, reason string) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	now := time.Now()
	updates := map[string]interface{}{
		"approved_by_id": actor.MemberID,
		"approved_at":    now,
	}
	if approve {
		// Re-check overlap at approval time
		var b models.HallBooking
		if err := r.db.First(&b, "id = ?", id).Error; err != nil {
			return err
		}
		var overlap int64
		r.db.Model(&models.HallBooking{}).
			Where("id != ? AND status = ?", id, models.HallBookingApproved).
			Where("start_time < ? AND end_time > ?", b.EndTime, b.StartTime).
			Count(&overlap)
		if overlap > 0 {
			return ErrSlotUnavailable
		}
		updates["status"] = models.HallBookingApproved
	} else {
		updates["status"] = models.HallBookingRejected
		updates["reject_reason"] = reason
	}
	return r.db.Model(&models.HallBooking{}).Where("id = ?", id).Updates(updates).Error
}

func (r *HallBookingRepository) Cancel(actor *ActorContext, id uuid.UUID) error {
	b, err := r.GetByID(actor, id)
	if err != nil {
		return err
	}
	return r.db.Model(b).Update("status", models.HallBookingCancelled).Error
}
