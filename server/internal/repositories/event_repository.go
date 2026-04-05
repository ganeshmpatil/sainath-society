package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type EventRepository struct {
	db *gorm.DB
}

func NewEventRepository(db *gorm.DB) *EventRepository {
	return &EventRepository{db: db}
}

// Create — admin only (committee members create events).
func (r *EventRepository) Create(actor *ActorContext, e *models.Event) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	e.OrganizerID = actor.MemberID
	return r.db.Create(e).Error
}

// ListUpcoming returns events scheduled in the future. Visible to everyone.
func (r *EventRepository) ListUpcoming(actor *ActorContext) ([]models.Event, error) {
	var rows []models.Event
	err := r.db.Preload("Organizer").
		Where("start_time >= ?", time.Now()).
		Where("status NOT IN ?", []models.EventStatus{models.EventCancelled}).
		Order("start_time ASC").Find(&rows).Error
	return rows, err
}

// ListAll — admins can see past + cancelled.
func (r *EventRepository) ListAll(actor *ActorContext) ([]models.Event, error) {
	q := r.db.Preload("Organizer").Order("start_time DESC")
	if !actor.IsAdmin() {
		q = q.Where("status != ?", models.EventCancelled)
	}
	var rows []models.Event
	err := q.Find(&rows).Error
	return rows, err
}

func (r *EventRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Event, error) {
	var e models.Event
	if err := r.db.Preload("Organizer").Preload("RSVPs").First(&e, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &e, nil
}

// RSVP allows any member to respond to an event.
func (r *EventRepository) RSVP(actor *ActorContext, eventID uuid.UUID, status models.RSVPStatus, guests int) error {
	rsvp := &models.EventRSVP{
		EventID:    eventID,
		MemberID:   actor.MemberID,
		Status:     status,
		GuestCount: guests,
	}
	// Upsert on uniqueIndex (event_id, member_id)
	return r.db.Where("event_id = ? AND member_id = ?", eventID, actor.MemberID).
		Assign(map[string]interface{}{
			"status":       status,
			"guest_count":  guests,
			"responded_at": time.Now(),
		}).
		FirstOrCreate(rsvp).Error
}
