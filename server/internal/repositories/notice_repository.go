package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type NoticeRepository struct {
	db *gorm.DB
}

func NewNoticeRepository(db *gorm.DB) *NoticeRepository {
	return &NoticeRepository{db: db}
}

// Create a notice — admin-only action.
func (r *NoticeRepository) Create(actor *ActorContext, n *models.Notice) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	n.CreatedByID = actor.MemberID
	return r.db.Create(n).Error
}

// List returns all currently visible notices to any member.
// Notices are globally readable, but unpublished / expired ones are hidden for non-admins.
func (r *NoticeRepository) List(actor *ActorContext) ([]models.Notice, error) {
	q := r.db.Model(&models.Notice{}).Preload("CreatedBy").
		Order("is_pinned DESC, created_at DESC")
	if !actor.IsAdmin() {
		now := time.Now()
		q = q.Where("is_published = ?", true).
			Where("(publish_at IS NULL OR publish_at <= ?)", now).
			Where("(expires_at IS NULL OR expires_at > ?)", now)
	}
	var rows []models.Notice
	err := q.Find(&rows).Error
	return rows, err
}

func (r *NoticeRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Notice, error) {
	var n models.Notice
	if err := r.db.Preload("CreatedBy").First(&n, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &n, nil
}

func (r *NoticeRepository) Update(actor *ActorContext, id uuid.UUID, patch map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.Notice{}).Where("id = ?", id).Updates(patch).Error
}

func (r *NoticeRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Delete(&models.Notice{}, "id = ?", id).Error
}
