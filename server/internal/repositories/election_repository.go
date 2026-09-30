package repositories

import (
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type ElectionRepository struct {
	db *gorm.DB
}

func NewElectionRepository(db *gorm.DB) *ElectionRepository {
	return &ElectionRepository{db: db}
}

// List returns all elections ordered by created_at descending.
func (r *ElectionRepository) List() ([]models.Election, error) {
	var rows []models.Election
	return rows, r.db.Order("created_at DESC").Find(&rows).Error
}

// GetByID returns an election with Positions and Candidates preloaded.
func (r *ElectionRepository) GetByID(id uuid.UUID) (*models.Election, error) {
	var e models.Election
	if err := r.db.
		Preload("Positions", func(db *gorm.DB) *gorm.DB {
			return db.Order("sort_order ASC")
		}).
		Preload("Candidates").
		First(&e, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &e, nil
}

// Create adds a new election. Admin only.
func (r *ElectionRepository) Create(actor *ActorContext, e *models.Election) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	e.CreatedByID = actor.MemberID
	return r.db.Create(e).Error
}

// Update modifies an election. Admin only.
func (r *ElectionRepository) Update(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.Election{}).Where("id = ?", id).Updates(updates)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// UpdateStatus changes the election status. Admin only.
func (r *ElectionRepository) UpdateStatus(actor *ActorContext, id uuid.UUID, status string) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.Election{}).Where("id = ?", id).Update("status", status)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// AddPosition adds a position to an election. Admin only.
func (r *ElectionRepository) AddPosition(actor *ActorContext, pos *models.ElectionPosition) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Create(pos).Error
}

// DeletePosition removes a position. Admin only.
func (r *ElectionRepository) DeletePosition(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Where("id = ?", id).Delete(&models.ElectionPosition{})
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// Nominate adds a candidate nomination. Members can self-nominate.
func (r *ElectionRepository) Nominate(actor *ActorContext, candidate *models.ElectionCandidate) error {
	candidate.MemberID = actor.MemberID
	candidate.Status = models.CandidateNominated
	return r.db.Create(candidate).Error
}

// ApproveCandidate sets candidate status to APPROVED. Admin only.
func (r *ElectionRepository) ApproveCandidate(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.ElectionCandidate{}).Where("id = ?", id).Updates(map[string]interface{}{
		"status":         models.CandidateApproved,
		"approved_by_id": actor.MemberID,
	})
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// RejectCandidate sets candidate status to REJECTED. Admin only.
func (r *ElectionRepository) RejectCandidate(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.ElectionCandidate{}).Where("id = ?", id).Update("status", models.CandidateRejected)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// WithdrawCandidate allows the candidate to withdraw their own nomination.
func (r *ElectionRepository) WithdrawCandidate(actor *ActorContext, id uuid.UUID) error {
	result := r.db.Model(&models.ElectionCandidate{}).
		Where("id = ? AND member_id = ?", id, actor.MemberID).
		Update("status", models.CandidateWithdrawn)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// CastVote records a vote. Validates that the election is in VOTING_OPEN status
// and the voter has not already voted for this position.
func (r *ElectionRepository) CastVote(actor *ActorContext, vote *models.ElectionVote) error {
	// Verify election is open for voting
	var election models.Election
	if err := r.db.First(&election, "id = ?", vote.ElectionID).Error; err != nil {
		return ErrNotFound
	}
	if election.Status != models.ElectionVotingOpen {
		return errors.New("voting is not open for this election")
	}

	// Check if already voted for this position
	already, err := r.HasVoted(vote.ElectionID, actor.MemberID, vote.PositionID)
	if err != nil {
		return err
	}
	if already {
		return errors.New("you have already voted for this position")
	}

	vote.VoterID = actor.MemberID
	return r.db.Create(vote).Error
}

// HasVoted checks whether the voter has already voted for a position in an election.
func (r *ElectionRepository) HasVoted(electionID, voterID, positionID uuid.UUID) (bool, error) {
	var count int64
	err := r.db.Model(&models.ElectionVote{}).
		Where("election_id = ? AND voter_id = ? AND position_id = ?", electionID, voterID, positionID).
		Count(&count).Error
	return count > 0, err
}

// PositionResult holds a candidate's vote tally for result display.
type PositionResult struct {
	PositionID    uuid.UUID `json:"positionId"`
	PositionTitle string    `json:"positionTitle"`
	CandidateID   uuid.UUID `json:"candidateId"`
	MemberName    string    `json:"memberName"`
	FlatNo        string    `json:"flatNo"`
	VoteCount     int       `json:"voteCount"`
}

// GetResults returns vote counts per candidate per position, ordered by votes descending.
func (r *ElectionRepository) GetResults(electionID uuid.UUID) ([]PositionResult, error) {
	var results []PositionResult
	err := r.db.Raw(`
		SELECT
			p.id AS position_id,
			p.title AS position_title,
			c.id AS candidate_id,
			c.member_name,
			c.flat_no,
			COUNT(v.id) AS vote_count
		FROM soc_mitra_election_positions p
		JOIN soc_mitra_election_candidates c ON c.position_id = p.id AND c.election_id = p.election_id AND c.status = 'APPROVED'
		LEFT JOIN soc_mitra_election_votes v ON v.candidate_id = c.id AND v.position_id = p.id
		WHERE p.election_id = ?
		GROUP BY p.id, p.title, p.sort_order, c.id, c.member_name, c.flat_no
		ORDER BY p.sort_order ASC, vote_count DESC
	`, electionID).Scan(&results).Error
	return results, err
}
