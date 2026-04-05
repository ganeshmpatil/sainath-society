package repositories

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type GrievanceRepository struct {
	db *gorm.DB
}

func NewGrievanceRepository(db *gorm.DB) *GrievanceRepository {
	return &GrievanceRepository{db: db}
}

// Create a new grievance. The raiser is set from the actor context so a
// member cannot impersonate another member.
func (r *GrievanceRepository) Create(actor *ActorContext, g *models.Grievance) error {
	g.RaisedByMemberID = actor.MemberID
	g.FlatID = actor.FlatID
	g.Status = models.GrievanceOpen
	g.TicketNo = generateTicketNo()
	return r.db.Create(g).Error
}

// List returns grievances visible to the actor.
//
//	Member → only own (raised_by_member_id = actor.MemberID)
//	Admin  → all
func (r *GrievanceRepository) List(actor *ActorContext, status *models.GrievanceStatus) ([]models.Grievance, error) {
	q := r.db.Model(&models.Grievance{}).
		Preload("RaisedBy").Preload("AssignedTo").Preload("Flat").
		Order("created_at DESC")
	q = ScopeOwnedOrAdmin(q, actor, "raised_by_member_id")
	if status != nil {
		q = q.Where("status = ?", *status)
	}
	var rows []models.Grievance
	err := q.Find(&rows).Error
	return rows, err
}

// GetByID returns a single grievance with ACL enforced.
func (r *GrievanceRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Grievance, error) {
	var g models.Grievance
	if err := r.db.Preload("RaisedBy").Preload("AssignedTo").Preload("Flat").
		Preload("Comments").First(&g, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, g.RaisedByMemberID); err != nil {
		return nil, err
	}
	return &g, nil
}

// UpdateStatus moves a grievance through its state machine. Only admins may
// change status; the raiser may only close their own grievance.
func (r *GrievanceRepository) UpdateStatus(actor *ActorContext, id uuid.UUID, status models.GrievanceStatus, resolution string) error {
	g, err := r.GetByID(actor, id)
	if err != nil {
		return err
	}
	if !actor.IsAdmin() && status != models.GrievanceClosed {
		return ErrForbidden
	}
	updates := map[string]interface{}{"status": status}
	if status == models.GrievanceResolved || status == models.GrievanceClosed {
		now := time.Now()
		updates["resolved_at"] = now
		updates["resolved_by_id"] = actor.MemberID
		if resolution != "" {
			updates["resolution"] = resolution
		}
	}
	return r.db.Model(g).Updates(updates).Error
}

// AddComment attaches a comment to a grievance (ACL enforced).
func (r *GrievanceRepository) AddComment(actor *ActorContext, grievanceID uuid.UUID, comment string, internal bool) error {
	if _, err := r.GetByID(actor, grievanceID); err != nil {
		return err
	}
	if internal && !actor.IsAdmin() {
		return ErrForbidden
	}
	c := &models.GrievanceComment{
		GrievanceID: grievanceID,
		AuthorID:    actor.MemberID,
		Comment:     comment,
		IsInternal:  internal,
	}
	return r.db.Create(c).Error
}

func generateTicketNo() string {
	return fmt.Sprintf("GRV-%d", time.Now().UnixNano()/1e6)
}
