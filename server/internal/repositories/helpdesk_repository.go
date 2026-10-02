package repositories

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type HelpdeskRepository struct {
	db *gorm.DB
}

func NewHelpdeskRepository(db *gorm.DB) *HelpdeskRepository {
	return &HelpdeskRepository{db: db}
}

// List returns helpdesk tickets, scoped to the actor's flat if not admin.
func (r *HelpdeskRepository) List(actor *ActorContext, status string, category string) ([]models.HelpdeskTicket, error) {
	q := r.db.Order("updated_at DESC").Limit(100)
	q = ScopeFlatOrAdmin(q, actor, "flat_id")
	if status != "" {
		q = q.Where("status = ?", status)
	}
	if category != "" {
		q = q.Where("category = ?", category)
	}
	var rows []models.HelpdeskTicket
	return rows, q.Find(&rows).Error
}

// GetByID returns a single ticket with its messages preloaded.
// Non-admin actors only see their own flat's tickets and cannot see internal messages.
func (r *HelpdeskRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.HelpdeskTicket, error) {
	var ticket models.HelpdeskTicket
	q := r.db
	if actor.IsAdmin() {
		q = q.Preload("Messages", func(db *gorm.DB) *gorm.DB {
			return db.Order("created_at ASC")
		})
	} else {
		q = q.Preload("Messages", func(db *gorm.DB) *gorm.DB {
			return db.Where("is_internal = ?", false).Order("created_at ASC")
		})
	}
	if err := q.First(&ticket, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	// Ownership check for non-admins
	if !actor.IsAdmin() {
		if actor.FlatID == nil || ticket.FlatID != *actor.FlatID {
			return nil, ErrForbidden
		}
	}
	return &ticket, nil
}

// Create adds a new helpdesk ticket with an auto-generated ticket number.
func (r *HelpdeskRepository) Create(actor *ActorContext, t *models.HelpdeskTicket) error {
	if actor == nil {
		return ErrForbidden
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		ticketNo, err := r.nextTicketNo(tx)
		if err != nil {
			return err
		}
		t.TicketNo = ticketNo
		t.RaisedByID = actor.MemberID
		t.Status = models.TicketOpen
		if t.Priority == "" {
			t.Priority = models.HelpdeskPriorityMedium
		}
		return tx.Create(t).Error
	})
}

// AddMessage appends a message to a ticket.
func (r *HelpdeskRepository) AddMessage(actor *ActorContext, msg *models.HelpdeskMessage) error {
	msg.SenderID = actor.MemberID
	if actor.IsAdmin() {
		msg.SenderRole = "ADMIN"
	} else {
		msg.SenderRole = "MEMBER"
		// Members cannot post internal notes
		msg.IsInternal = false
	}
	// Look up sender name from members table if not already set
	if msg.SenderName == "" {
		var name string
		r.db.Model(&models.Member{}).Select("name").Where("id = ?", actor.MemberID).Row().Scan(&name)
		msg.SenderName = name
	}
	if err := r.db.Create(msg).Error; err != nil {
		return err
	}
	// Touch the ticket's updated_at so it surfaces in the list
	return r.db.Model(&models.HelpdeskTicket{}).Where("id = ?", msg.TicketID).
		Update("updated_at", time.Now()).Error
}

// UpdateStatus changes the status of a ticket. Admin only.
func (r *HelpdeskRepository) UpdateStatus(actor *ActorContext, id uuid.UUID, status string) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	updates := map[string]interface{}{"status": status}
	now := time.Now()
	if status == string(models.TicketResolved) {
		updates["resolved_at"] = now
	}
	if status == string(models.TicketClosed) {
		updates["closed_at"] = now
	}
	result := r.db.Model(&models.HelpdeskTicket{}).Where("id = ?", id).Updates(updates)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// Assign sets the committee member handling a ticket. Admin only.
func (r *HelpdeskRepository) Assign(actor *ActorContext, id uuid.UUID, assigneeID uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.HelpdeskTicket{}).Where("id = ?", id).
		Update("assigned_to_id", assigneeID)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// Stats returns counts of tickets grouped by status.
func (r *HelpdeskRepository) Stats() (map[string]int64, error) {
	type row struct {
		Status string
		Count  int64
	}
	var rows []row
	err := r.db.Model(&models.HelpdeskTicket{}).
		Select("status, count(*) as count").
		Group("status").Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	stats := map[string]int64{
		"open":       0,
		"inProgress": 0,
		"resolved":   0,
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
		case "CLOSED":
			stats["closed"] = r.Count
		}
	}
	return stats, nil
}

// nextTicketNo generates the next ticket number (HD-001, HD-002, ...).
// Must be called inside a transaction to avoid race conditions.
func (r *HelpdeskRepository) nextTicketNo(tx *gorm.DB) (string, error) {
	var lastNo string
	err := tx.Model(&models.HelpdeskTicket{}).
		Select("ticket_no").
		Order("created_at DESC").
		Limit(1).
		Pluck("ticket_no", &lastNo).Error
	if err != nil || lastNo == "" {
		return "HD-001", nil
	}
	parts := strings.Split(lastNo, "-")
	if len(parts) != 2 {
		return "HD-001", nil
	}
	num, err := strconv.Atoi(parts[1])
	if err != nil {
		return "HD-001", nil
	}
	return fmt.Sprintf("HD-%03d", num+1), nil
}
