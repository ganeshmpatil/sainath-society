package repositories

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
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

	// Default type to COMPLAINT if not set
	if g.Type == "" {
		g.Type = models.GrievanceTypeComplaint
	}

	// Look up flat_no from flats table if not provided and actor has a flat
	if g.FlatNo == "" && actor.FlatID != nil {
		var flatNo string
		r.db.Model(&models.Flat{}).Select("flat_number").
			Where("id = ?", *actor.FlatID).Row().Scan(&flatNo)
		g.FlatNo = flatNo
	}

	return r.db.Create(g).Error
}

// List returns grievances visible to the actor.
//
//	Member → only own (raised_by_member_id = actor.MemberID)
//	Admin  → all
func (r *GrievanceRepository) List(actor *ActorContext, status *models.GrievanceStatus, category *models.GrievanceCategory, gType *models.GrievanceType) ([]models.Grievance, error) {
	q := r.db.Model(&models.Grievance{}).
		Preload("RaisedBy").Preload("AssignedTo").Preload("Flat").
		Order("created_at DESC")
	q = ScopeOwnedOrAdmin(q, actor, "raised_by_member_id")
	if status != nil {
		q = q.Where("status = ?", *status)
	}
	if category != nil {
		q = q.Where("category = ?", *category)
	}
	if gType != nil {
		q = q.Where("type = ?", *gType)
	}
	var rows []models.Grievance
	err := q.Find(&rows).Error
	return rows, err
}

// GetByID returns a single grievance with ACL enforced.
// Non-admin actors cannot see internal comments.
func (r *GrievanceRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Grievance, error) {
	var g models.Grievance
	q := r.db.Preload("RaisedBy").Preload("AssignedTo").Preload("Flat")

	// Filter out internal comments for non-admins
	if actor.IsAdmin() {
		q = q.Preload("Comments", func(db *gorm.DB) *gorm.DB {
			return db.Order("created_at ASC")
		})
	} else {
		q = q.Preload("Comments", func(db *gorm.DB) *gorm.DB {
			return db.Where("is_internal = ?", false).Order("created_at ASC")
		})
	}

	if err := q.First(&g, "id = ?", id).Error; err != nil {
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
	if status == models.GrievanceClosed {
		now := time.Now()
		updates["closed_at"] = now
	}
	return r.db.Model(g).Updates(updates).Error
}

// AddComment attaches a comment to a grievance (ACL enforced).
// It looks up the author name from the members table and sets the role.
func (r *GrievanceRepository) AddComment(actor *ActorContext, grievanceID uuid.UUID, comment string, internal bool) (*models.GrievanceComment, error) {
	if _, err := r.GetByID(actor, grievanceID); err != nil {
		return nil, err
	}
	if internal && !actor.IsAdmin() {
		return nil, ErrForbidden
	}

	// Determine author role
	authorRole := "MEMBER"
	if actor.IsAdmin() {
		authorRole = "ADMIN"
	}

	// Look up author name from members table
	var authorName string
	r.db.Model(&models.Member{}).Select("name").
		Where("id = ?", actor.MemberID).Row().Scan(&authorName)

	c := &models.GrievanceComment{
		GrievanceID: grievanceID,
		AuthorID:    actor.MemberID,
		AuthorName:  authorName,
		AuthorRole:  authorRole,
		Comment:     comment,
		IsInternal:  internal,
	}
	if err := r.db.Create(c).Error; err != nil {
		return nil, err
	}
	return c, nil
}

// Stats returns counts of grievances grouped by status.
func (r *GrievanceRepository) Stats() (map[string]int64, error) {
	type row struct {
		Status string
		Count  int64
	}
	var rows []row
	err := r.db.Model(&models.Grievance{}).
		Select("status, count(*) as count").
		Group("status").Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	stats := map[string]int64{
		"open":       0,
		"inProgress": 0,
		"resolved":   0,
		"rejected":   0,
		"closed":     0,
	}
	for _, r := range rows {
		switch r.Status {
		case "OPEN":
			stats["open"] = r.Count
		case "IN_PROGRESS":
			stats["inProgress"] = r.Count
		case "RESOLVED":
			stats["resolved"] = r.Count
		case "REJECTED":
			stats["rejected"] = r.Count
		case "CLOSED":
			stats["closed"] = r.Count
		}
	}
	return stats, nil
}

// Assign sets the committee member handling a grievance. Admin only.
func (r *GrievanceRepository) Assign(actor *ActorContext, id uuid.UUID, assigneeID uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	now := time.Now()
	result := r.db.Model(&models.Grievance{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"assigned_to_member_id": assigneeID,
			"assigned_at":           now,
		})
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

func generateTicketNo() string {
	return fmt.Sprintf("GRV-%d", time.Now().UnixNano()/1e6)
}
