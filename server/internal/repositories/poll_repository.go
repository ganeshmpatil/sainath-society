package repositories

import (
	"errors"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

var ErrAlreadyVoted = errors.New("this flat has already voted on this poll")
var ErrPollInactive = errors.New("poll is not currently accepting votes")

type PollRepository struct {
	db *gorm.DB
}

func NewPollRepository(db *gorm.DB) *PollRepository {
	return &PollRepository{db: db}
}

// Create a poll with its options atomically. Admin-only.
func (r *PollRepository) Create(actor *ActorContext, p *models.Poll, options []models.PollOption) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	p.CreatedByID = actor.MemberID
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(p).Error; err != nil {
			return err
		}
		for i := range options {
			options[i].PollID = p.ID
			options[i].Order = i
		}
		if len(options) > 0 {
			if err := tx.Create(&options).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

// List all polls visible to the member. Drafts are admin-only.
func (r *PollRepository) List(actor *ActorContext) ([]models.Poll, error) {
	q := r.db.Preload("Options").Order("created_at DESC")
	if !actor.IsAdmin() {
		q = q.Where("status != ?", models.PollDraft)
	}
	var rows []models.Poll
	err := q.Find(&rows).Error
	return rows, err
}

func (r *PollRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Poll, error) {
	var p models.Poll
	if err := r.db.Preload("Options").First(&p, "id = ?", id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if p.Status == models.PollDraft && !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	return &p, nil
}

// Publish transitions DRAFT → ACTIVE. Admin-only.
func (r *PollRepository) Publish(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.Poll{}).Where("id = ?", id).
		Update("status", models.PollActive).Error
}

// Close a poll manually. Admin-only.
func (r *PollRepository) Close(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.Poll{}).Where("id = ?", id).
		Update("status", models.PollClosed).Error
}

// Vote records a single flat-level vote.
// Enforces:
//   1. Actor's flat is set
//   2. Poll is ACTIVE and within window
//   3. No prior vote exists for this flat on this poll (unique index + lookup)
func (r *PollRepository) Vote(actor *ActorContext, pollID, optionID uuid.UUID) error {
	if actor.FlatID == nil {
		return ErrForbidden
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		var p models.Poll
		if err := tx.First(&p, "id = ?", pollID).Error; err != nil {
			return ErrNotFound
		}
		now := time.Now()
		if p.Status != models.PollActive || now.Before(p.StartsAt) || now.After(p.EndsAt) {
			return ErrPollInactive
		}

		// Ensure option belongs to this poll
		var opt models.PollOption
		if err := tx.Where("id = ? AND poll_id = ?", optionID, pollID).First(&opt).Error; err != nil {
			return ErrNotFound
		}

		// Reject duplicate vote (unique index would also catch but we want a nice error)
		var existing int64
		tx.Model(&models.PollVote{}).
			Where("poll_id = ? AND flat_id = ?", pollID, *actor.FlatID).
			Count(&existing)
		if existing > 0 {
			return ErrAlreadyVoted
		}

		vote := &models.PollVote{
			PollID:    pollID,
			FlatID:    *actor.FlatID,
			OptionID:  optionID,
			VotedByID: actor.MemberID,
		}
		if err := tx.Create(vote).Error; err != nil {
			return err
		}
		return tx.Model(&models.PollOption{}).Where("id = ?", optionID).
			UpdateColumn("vote_count", gorm.Expr("vote_count + 1")).Error
	})
}

// Results returns tallied options (vote_count) and total votes cast.
func (r *PollRepository) Results(actor *ActorContext, pollID uuid.UUID) (*models.Poll, int64, error) {
	p, err := r.GetByID(actor, pollID)
	if err != nil {
		return nil, 0, err
	}
	var total int64
	r.db.Model(&models.PollVote{}).Where("poll_id = ?", pollID).Count(&total)
	return p, total, nil
}
