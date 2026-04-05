package repositories

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

var ErrAlreadyUpvoted = errors.New("member has already upvoted this suggestion")

type SuggestionRepository struct {
	db *gorm.DB
}

func NewSuggestionRepository(db *gorm.DB) *SuggestionRepository {
	return &SuggestionRepository{db: db}
}

// Create a suggestion. Raiser is always set from actor so members can't spoof.
func (r *SuggestionRepository) Create(actor *ActorContext, s *models.Suggestion) error {
	s.RaisedByMemberID = actor.MemberID
	s.Status = models.SuggestionProposed
	return r.db.Create(s).Error
}

// List all suggestions (public read). Sort by upvotes desc by default.
func (r *SuggestionRepository) List(actor *ActorContext, sortBy string) ([]models.Suggestion, error) {
	order := "upvote_count DESC, created_at DESC"
	if sortBy == "recent" {
		order = "created_at DESC"
	}
	var rows []models.Suggestion
	err := r.db.Preload("RaisedBy").Order(order).Find(&rows).Error
	return rows, err
}

func (r *SuggestionRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Suggestion, error) {
	var s models.Suggestion
	if err := r.db.Preload("RaisedBy").First(&s, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &s, nil
}

// Upvote increments the counter and records the upvoter. One per member.
func (r *SuggestionRepository) Upvote(actor *ActorContext, suggestionID uuid.UUID) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		var count int64
		tx.Model(&models.SuggestionUpvote{}).
			Where("suggestion_id = ? AND member_id = ?", suggestionID, actor.MemberID).
			Count(&count)
		if count > 0 {
			return ErrAlreadyUpvoted
		}
		upvote := &models.SuggestionUpvote{
			SuggestionID: suggestionID,
			MemberID:     actor.MemberID,
		}
		if err := tx.Create(upvote).Error; err != nil {
			return err
		}
		return tx.Model(&models.Suggestion{}).Where("id = ?", suggestionID).
			UpdateColumn("upvote_count", gorm.Expr("upvote_count + 1")).Error
	})
}

// Respond lets an admin set the official response and update status.
func (r *SuggestionRepository) Respond(actor *ActorContext, id uuid.UUID, status models.SuggestionStatus, response, responseMr string) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	now := time.Now()
	return r.db.Model(&models.Suggestion{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"status":            status,
			"admin_response":    response,
			"admin_response_mr": responseMr,
			"responded_by_id":   actor.MemberID,
			"responded_at":      now,
		}).Error
}
