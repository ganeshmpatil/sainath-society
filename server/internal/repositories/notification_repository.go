package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type NotificationRepository struct {
	db *gorm.DB
}

func NewNotificationRepository(db *gorm.DB) *NotificationRepository {
	return &NotificationRepository{db: db}
}

// Enqueue queues a notification for dispatch. Called by other repositories /
// services (e.g. after creating a grievance or task).
func (r *NotificationRepository) Enqueue(n *models.Notification) error {
	n.Status = models.NotifPending
	return r.db.Create(n).Error
}

// PendingForDispatch returns up to `limit` notifications waiting to be sent.
// Used by the worker/cron that talks to WhatsApp / SMS providers.
func (r *NotificationRepository) PendingForDispatch(limit int) ([]models.Notification, error) {
	var rows []models.Notification
	err := r.db.Preload("Recipient").
		Where("status = ?", models.NotifPending).
		Where("retry_count < 5").
		Order("created_at ASC").
		Limit(limit).Find(&rows).Error
	return rows, err
}

// MarkSent records a successful dispatch with the provider reference id.
func (r *NotificationRepository) MarkSent(id uuid.UUID, providerRef string) error {
	now := time.Now()
	return r.db.Model(&models.Notification{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"status":       models.NotifSent,
			"provider_ref": providerRef,
			"sent_at":      now,
		}).Error
}

// MarkFailed records a dispatch failure and increments retry count.
func (r *NotificationRepository) MarkFailed(id uuid.UUID, reason string) error {
	return r.db.Model(&models.Notification{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"status":         models.NotifFailed,
			"failure_reason": reason,
			"retry_count":    gorm.Expr("retry_count + 1"),
		}).Error
}

// ListForRecipient returns notifications delivered to the actor (in-app inbox).
func (r *NotificationRepository) ListForRecipient(actor *ActorContext) ([]models.Notification, error) {
	var rows []models.Notification
	err := r.db.Where("recipient_id = ?", actor.MemberID).
		Order("created_at DESC").Limit(100).Find(&rows).Error
	return rows, err
}
