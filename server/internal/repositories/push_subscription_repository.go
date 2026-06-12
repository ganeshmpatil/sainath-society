package repositories

import (
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"sainath-society/internal/models"
)

type PushSubscriptionRepository struct {
	db *gorm.DB
}

func NewPushSubscriptionRepository(db *gorm.DB) *PushSubscriptionRepository {
	return &PushSubscriptionRepository{db: db}
}

// Upsert creates or updates a push subscription. If the endpoint already
// exists it updates the keys and re-activates.
func (r *PushSubscriptionRepository) Upsert(sub *models.PushSubscription) error {
	return r.db.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "endpoint"}},
		DoUpdates: clause.AssignmentColumns([]string{"member_id", "key_p256dh", "key_auth", "user_agent", "is_active", "updated_at"}),
	}).Create(sub).Error
}

// Delete removes a subscription by endpoint.
func (r *PushSubscriptionRepository) Delete(endpoint string) error {
	return r.db.Where("endpoint = ?", endpoint).Delete(&models.PushSubscription{}).Error
}

// DeactivateByEndpoint marks a subscription inactive (e.g. when push delivery
// returns 410 Gone, meaning the browser unsubscribed).
func (r *PushSubscriptionRepository) DeactivateByEndpoint(endpoint string) error {
	return r.db.Model(&models.PushSubscription{}).
		Where("endpoint = ?", endpoint).
		Update("is_active", false).Error
}

// ListForMember returns all active subscriptions for a member (all their devices).
func (r *PushSubscriptionRepository) ListForMember(memberID uuid.UUID) ([]models.PushSubscription, error) {
	var rows []models.PushSubscription
	err := r.db.Where("member_id = ? AND is_active = ?", memberID, true).Find(&rows).Error
	return rows, err
}

// ListForMembers returns active subscriptions for a list of member IDs (batch push).
func (r *PushSubscriptionRepository) ListForMembers(memberIDs []uuid.UUID) ([]models.PushSubscription, error) {
	var rows []models.PushSubscription
	err := r.db.Where("member_id IN ? AND is_active = ?", memberIDs, true).Find(&rows).Error
	return rows, err
}

// ListAll returns all active subscriptions (for broadcast).
func (r *PushSubscriptionRepository) ListAll() ([]models.PushSubscription, error) {
	var rows []models.PushSubscription
	err := r.db.Where("is_active = ?", true).Find(&rows).Error
	return rows, err
}
