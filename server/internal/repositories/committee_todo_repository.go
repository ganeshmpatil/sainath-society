package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type CommitteeTodoRepository struct {
	db *gorm.DB
}

func NewCommitteeTodoRepository(db *gorm.DB) *CommitteeTodoRepository {
	return &CommitteeTodoRepository{db: db}
}

// Create adds a new committee todo. Admin only.
func (r *CommitteeTodoRepository) Create(actor *ActorContext, ct *models.CommitteeTodo) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	ct.CreatedByMemberID = actor.MemberID
	return r.db.Create(ct).Error
}

// ListByMonth returns all active todos for a given year/month (for calendar view).
// Visible to everyone. Also includes overdue items from previous months.
func (r *CommitteeTodoRepository) ListByMonth(year, month int) ([]models.CommitteeTodo, error) {
	start := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
	end := start.AddDate(0, 1, 0)

	var rows []models.CommitteeTodo
	err := r.db.
		Where("is_active = ?", true).
		Where(
			// Items due in the requested month OR overdue items from before
			"(due_date >= ? AND due_date < ?) OR (due_date < ? AND status NOT IN (?, ?))",
			start, end, start, models.TodoCompleted, models.TodoCancelled,
		).
		Preload("AssignedTo").Preload("CreatedBy").
		Order("due_date ASC").
		Find(&rows).Error
	return rows, err
}

// ListAll returns all active todos ordered by due date.
func (r *CommitteeTodoRepository) ListAll() ([]models.CommitteeTodo, error) {
	var rows []models.CommitteeTodo
	err := r.db.
		Where("is_active = ?", true).
		Preload("AssignedTo").Preload("CreatedBy").
		Order("due_date ASC").
		Find(&rows).Error
	return rows, err
}

// GetByID returns a single todo.
func (r *CommitteeTodoRepository) GetByID(id uuid.UUID) (*models.CommitteeTodo, error) {
	var ct models.CommitteeTodo
	if err := r.db.Preload("AssignedTo").Preload("CreatedBy").First(&ct, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &ct, nil
}

// Update modifies a todo. Admin only.
func (r *CommitteeTodoRepository) Update(actor *ActorContext, id uuid.UUID, patch map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	ct, err := r.GetByID(id)
	if err != nil {
		return err
	}
	return r.db.Model(ct).Updates(patch).Error
}

// UpdateStatus transitions the status of a todo. Admin only.
func (r *CommitteeTodoRepository) UpdateStatus(actor *ActorContext, id uuid.UUID, status models.TodoStatus) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	ct, err := r.GetByID(id)
	if err != nil {
		return err
	}
	updates := map[string]interface{}{"status": status}
	if status == models.TodoCompleted {
		now := time.Now()
		updates["completed_at"] = &now
	}
	if status == models.TodoInProgress && ct.Status == models.TodoPending {
		// no extra timestamp needed, just status change
	}
	return r.db.Model(ct).Updates(updates).Error
}

// Delete soft-deletes a todo. Admin only.
func (r *CommitteeTodoRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	ct, err := r.GetByID(id)
	if err != nil {
		return err
	}
	return r.db.Model(ct).Update("is_active", false).Error
}
