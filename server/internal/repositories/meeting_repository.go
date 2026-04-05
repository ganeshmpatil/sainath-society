package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type MeetingRepository struct {
	db *gorm.DB
}

func NewMeetingRepository(db *gorm.DB) *MeetingRepository {
	return &MeetingRepository{db: db}
}

// Create a meeting — admin only.
func (r *MeetingRepository) Create(actor *ActorContext, m *models.Meeting) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	m.CalledByID = actor.MemberID
	return r.db.Create(m).Error
}

// List returns meetings visible to actor. Committee meetings are hidden from
// regular members; AGMs/SGMs are visible to everyone.
func (r *MeetingRepository) List(actor *ActorContext) ([]models.Meeting, error) {
	q := r.db.Model(&models.Meeting{}).Order("scheduled_at DESC")
	if !actor.IsAdmin() {
		q = q.Where("meeting_type NOT IN ?", []models.MeetingType{models.MeetingCommittee})
	}
	var rows []models.Meeting
	err := q.Find(&rows).Error
	return rows, err
}

// GetByID fetches a meeting with attendees + action items.
func (r *MeetingRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Meeting, error) {
	var m models.Meeting
	err := r.db.Preload("Attendees.Member").Preload("ActionItems.Owner").Preload("Documents").
		First(&m, "id = ?", id).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	// Committee meetings hidden from non-admins
	if !actor.IsAdmin() && m.MeetingType == models.MeetingCommittee {
		return nil, ErrForbidden
	}
	return &m, nil
}

// MarkAttendance upserts attendance for a member.
func (r *MeetingRepository) MarkAttendance(actor *ActorContext, meetingID, memberID uuid.UUID, status models.AttendanceStatus) error {
	if !actor.IsAdmin() && actor.MemberID != memberID {
		return ErrForbidden
	}
	att := &models.MeetingAttendee{
		MeetingID: meetingID,
		MemberID:  memberID,
		Status:    status,
	}
	return r.db.Where("meeting_id = ? AND member_id = ?", meetingID, memberID).
		Assign(map[string]interface{}{"status": status}).
		FirstOrCreate(att).Error
}

// SaveMinutes writes MoM. Only admin, and only before minutes are locked.
func (r *MeetingRepository) SaveMinutes(actor *ActorContext, meetingID uuid.UUID, minutes, minutesMr string, lock bool) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	var m models.Meeting
	if err := r.db.First(&m, "id = ?", meetingID).Error; err != nil {
		return err
	}
	if m.MinutesLockedAt != nil {
		return ErrForbidden
	}
	updates := map[string]interface{}{
		"minutes_of_meeting":    minutes,
		"minutes_of_meeting_mr": minutesMr,
		"status":                models.MeetingCompleted,
	}
	if lock {
		now := time.Now()
		updates["minutes_locked_at"] = now
	}
	return r.db.Model(&m).Updates(updates).Error
}

// AddActionItem — admin only, during or after a meeting.
func (r *MeetingRepository) AddActionItem(actor *ActorContext, item *models.MeetingActionItem) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Create(item).Error
}

// ListActionItemsForMember — returns every meeting action item owned by a member.
// Members can only see their own; admins can see anyone's.
func (r *MeetingRepository) ListActionItemsForMember(actor *ActorContext, memberID uuid.UUID) ([]models.MeetingActionItem, error) {
	if !actor.IsAdmin() && actor.MemberID != memberID {
		return nil, ErrForbidden
	}
	var rows []models.MeetingActionItem
	err := r.db.Where("owner_member_id = ?", memberID).
		Order("due_date ASC").Find(&rows).Error
	return rows, err
}
