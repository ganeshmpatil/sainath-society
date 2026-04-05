package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type TaskRepository struct {
	db *gorm.DB
}

func NewTaskRepository(db *gorm.DB) *TaskRepository {
	return &TaskRepository{db: db}
}

// Create a task.
//   - Member: can only create tasks for themselves
//   - Admin:  can assign tasks to any member
func (r *TaskRepository) Create(actor *ActorContext, t *models.Task) error {
	t.AssignedByID = actor.MemberID
	if !actor.IsAdmin() {
		t.OwnerMemberID = actor.MemberID
	}
	return r.db.Create(t).Error
}

// ListPending returns pending tasks for the actor.
//   - Member: only own
//   - Admin: all (optionally filtered by owner)
func (r *TaskRepository) ListPending(actor *ActorContext, ownerFilter *uuid.UUID) ([]models.Task, error) {
	q := r.db.Model(&models.Task{}).Preload("Owner").Preload("AssignedBy").
		Where("status IN ?", []models.TaskStatus{models.TaskPending, models.TaskInProgress, models.TaskOverdue}).
		Order("due_date ASC")
	if !actor.IsAdmin() {
		q = q.Where("owner_member_id = ?", actor.MemberID)
	} else if ownerFilter != nil {
		q = q.Where("owner_member_id = ?", *ownerFilter)
	}
	var rows []models.Task
	err := q.Find(&rows).Error
	return rows, err
}

// ListAll — paginated list of all tasks for the actor (any status).
func (r *TaskRepository) ListAll(actor *ActorContext) ([]models.Task, error) {
	q := r.db.Model(&models.Task{}).Preload("Owner").Preload("AssignedBy").Order("created_at DESC")
	q = ScopeOwnedOrAdmin(q, actor, "owner_member_id")
	var rows []models.Task
	err := q.Find(&rows).Error
	return rows, err
}

func (r *TaskRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.Task, error) {
	var t models.Task
	if err := r.db.Preload("Owner").Preload("AssignedBy").First(&t, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if err := AssertOwnerOrAdmin(actor, t.OwnerMemberID); err != nil {
		return nil, err
	}
	return &t, nil
}

// UpdateStatus — owner or admin may transition status.
func (r *TaskRepository) UpdateStatus(actor *ActorContext, id uuid.UUID, status models.TaskStatus) error {
	t, err := r.GetByID(actor, id)
	if err != nil {
		return err
	}
	updates := map[string]interface{}{"status": status}
	now := time.Now()
	switch status {
	case models.TaskInProgress:
		if t.StartedAt == nil {
			updates["started_at"] = now
		}
	case models.TaskCompleted:
		updates["completed_at"] = now
	}
	return r.db.Model(t).Updates(updates).Error
}

// FindOverdue returns tasks past due date that are still pending/in-progress.
// Used by the reminder/escalation worker.
func (r *TaskRepository) FindOverdue() ([]models.Task, error) {
	var rows []models.Task
	err := r.db.Where("due_date < ?", time.Now()).
		Where("status IN ?", []models.TaskStatus{models.TaskPending, models.TaskInProgress}).
		Find(&rows).Error
	return rows, err
}
