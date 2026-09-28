package repositories

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type WorkflowRepository struct {
	db *gorm.DB
}

func NewWorkflowRepository(db *gorm.DB) *WorkflowRepository {
	return &WorkflowRepository{db: db}
}

// ─── Workflow CRUD ───────────────────────────────────────────────

func (r *WorkflowRepository) Create(actor *ActorContext, wf *models.Workflow) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	wf.CreatedByMemberID = actor.MemberID
	if err := r.db.Create(wf).Error; err != nil {
		return err
	}
	r.logAudit(wf.ID, nil, actor.MemberID, "CREATED", "", string(wf.Status), "Workflow created: "+wf.Title)
	return nil
}

func (r *WorkflowRepository) List(status string, isTemplate bool) ([]models.Workflow, error) {
	q := r.db.Where("is_active = ? AND is_template = ?", true, isTemplate)
	if status != "" {
		q = q.Where("status = ?", status)
	}
	var rows []models.Workflow
	err := q.
		Preload("CreatedBy").
		Preload("Activities", func(db *gorm.DB) *gorm.DB { return db.Order("position ASC") }).
		Order("updated_at DESC").
		Find(&rows).Error
	return rows, err
}

func (r *WorkflowRepository) GetByID(id uuid.UUID) (*models.Workflow, error) {
	var wf models.Workflow
	err := r.db.
		Preload("CreatedBy").
		Preload("Activities", func(db *gorm.DB) *gorm.DB { return db.Order("position ASC") }).
		Preload("Activities.AssignedTo").
		Preload("Activities.CompletedBy").
		Preload("Activities.Comments", func(db *gorm.DB) *gorm.DB { return db.Order("created_at ASC") }).
		Preload("Activities.Comments.Member").
		Preload("Activities.Attachments").
		Preload("Activities.Attachments.UploadedBy").
		First(&wf, "id = ?", id).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &wf, nil
}

func (r *WorkflowRepository) Update(actor *ActorContext, id uuid.UUID, patch map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	wf, err := r.GetByID(id)
	if err != nil {
		return err
	}
	if err := r.db.Model(wf).Updates(patch).Error; err != nil {
		return err
	}
	r.logAudit(id, nil, actor.MemberID, "UPDATED", "", "", "Workflow updated")
	return nil
}

func (r *WorkflowRepository) UpdateStatus(actor *ActorContext, id uuid.UUID, status models.WorkflowStatus) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	wf, err := r.GetByID(id)
	if err != nil {
		return err
	}
	old := wf.Status
	updates := map[string]interface{}{"status": status}
	now := time.Now()
	if status == models.WorkflowActive && wf.StartedAt == nil {
		updates["started_at"] = &now
	}
	if status == models.WorkflowCompleted {
		updates["completed_at"] = &now
	}
	if err := r.db.Model(wf).Updates(updates).Error; err != nil {
		return err
	}
	r.logAudit(id, nil, actor.MemberID, "STATUS_CHANGED", string(old), string(status), "")
	return nil
}

func (r *WorkflowRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	wf, err := r.GetByID(id)
	if err != nil {
		return err
	}
	return r.db.Model(wf).Update("is_active", false).Error
}

// Instantiate clones a template into a new active workflow.
func (r *WorkflowRepository) Instantiate(actor *ActorContext, templateID uuid.UUID, title, titleMr string, targetDate *time.Time) (*models.Workflow, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	tmpl, err := r.GetByID(templateID)
	if err != nil {
		return nil, err
	}
	if !tmpl.IsTemplate {
		return nil, fmt.Errorf("not a template")
	}

	wf := &models.Workflow{
		Title:             title,
		TitleMr:           titleMr,
		Description:       tmpl.Description,
		DescriptionMr:     tmpl.DescriptionMr,
		Category:          tmpl.Category,
		Status:            models.WorkflowDraft,
		IsTemplate:        false,
		TemplateID:        &templateID,
		TargetDate:        targetDate,
		CreatedByMemberID: actor.MemberID,
		IsActive:          true,
	}

	err = r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(wf).Error; err != nil {
			return err
		}
		for _, a := range tmpl.Activities {
			act := models.WorkflowActivity{
				WorkflowID:    wf.ID,
				Title:         a.Title,
				TitleMr:       a.TitleMr,
				Description:   a.Description,
				DescriptionMr: a.DescriptionMr,
				Position:      a.Position,
				Status:        models.ActivityPending,
			}
			if err := tx.Create(&act).Error; err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	r.logAudit(wf.ID, nil, actor.MemberID, "CREATED", "", "DRAFT", "Instantiated from template: "+tmpl.Title)
	return r.GetByID(wf.ID)
}

// ─── Activity CRUD ───────────────────────────────────────────────

func (r *WorkflowRepository) AddActivity(actor *ActorContext, wfID uuid.UUID, act *models.WorkflowActivity) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	// Auto-assign position as last
	var maxPos int
	r.db.Model(&models.WorkflowActivity{}).Where("workflow_id = ?", wfID).Select("COALESCE(MAX(position), -1)").Scan(&maxPos)
	act.WorkflowID = wfID
	act.Position = maxPos + 1
	act.Status = models.ActivityPending
	if err := r.db.Create(act).Error; err != nil {
		return err
	}
	r.logAudit(wfID, &act.ID, actor.MemberID, "ACTIVITY_ADDED", "", "", "Added: "+act.Title)
	return nil
}

func (r *WorkflowRepository) UpdateActivity(actor *ActorContext, wfID, actID uuid.UUID, patch map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	var act models.WorkflowActivity
	if err := r.db.First(&act, "id = ? AND workflow_id = ?", actID, wfID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return ErrNotFound
		}
		return err
	}
	if err := r.db.Model(&act).Updates(patch).Error; err != nil {
		return err
	}
	r.logAudit(wfID, &actID, actor.MemberID, "UPDATED", "", "", "Activity updated: "+act.Title)
	return nil
}

func (r *WorkflowRepository) UpdateActivityStatus(actor *ActorContext, wfID, actID uuid.UUID, status models.ActivityStatus) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}

	var act models.WorkflowActivity
	if err := r.db.First(&act, "id = ? AND workflow_id = ?", actID, wfID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return ErrNotFound
		}
		return err
	}

	old := act.Status
	updates := map[string]interface{}{"status": status}
	if status == models.ActivityCompleted || status == models.ActivitySkipped {
		now := time.Now()
		updates["completed_at"] = &now
		updates["completed_by_id"] = actor.MemberID
	}
	if err := r.db.Model(&act).Updates(updates).Error; err != nil {
		return err
	}
	r.logAudit(wfID, &actID, actor.MemberID, "STATUS_CHANGED", string(old), string(status), act.Title)

	// Auto-complete workflow if all activities done
	r.checkAutoComplete(wfID, actor.MemberID)
	return nil
}

func (r *WorkflowRepository) ReorderActivities(actor *ActorContext, wfID uuid.UUID, activityIDs []uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Transaction(func(tx *gorm.DB) error {
		for i, id := range activityIDs {
			if err := tx.Model(&models.WorkflowActivity{}).
				Where("id = ? AND workflow_id = ?", id, wfID).
				Update("position", i).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

func (r *WorkflowRepository) DeleteActivity(actor *ActorContext, wfID, actID uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	var act models.WorkflowActivity
	if err := r.db.First(&act, "id = ? AND workflow_id = ?", actID, wfID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return ErrNotFound
		}
		return err
	}
	if err := r.db.Delete(&act).Error; err != nil {
		return err
	}
	r.logAudit(wfID, &actID, actor.MemberID, "ACTIVITY_REMOVED", "", "", "Removed: "+act.Title)
	return nil
}

// ─── Comments ────────────────────────────────────────────────────

func (r *WorkflowRepository) AddComment(actor *ActorContext, wfID, actID uuid.UUID, body string) (*models.WorkflowActivityComment, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	comment := &models.WorkflowActivityComment{
		ActivityID: actID,
		MemberID:   actor.MemberID,
		Body:       body,
	}
	if err := r.db.Create(comment).Error; err != nil {
		return nil, err
	}
	r.logAudit(wfID, &actID, actor.MemberID, "COMMENT_ADDED", "", "", body)
	return comment, nil
}

// ─── Attachments ─────────────────────────────────────────────────

func (r *WorkflowRepository) AddAttachment(actor *ActorContext, wfID uuid.UUID, att *models.WorkflowActivityAttachment) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	if err := r.db.Create(att).Error; err != nil {
		return err
	}
	r.logAudit(wfID, &att.ActivityID, actor.MemberID, "ATTACHMENT_ADDED", "", "", att.FileName)
	return nil
}

func (r *WorkflowRepository) GetAttachment(id uuid.UUID) (*models.WorkflowActivityAttachment, error) {
	var att models.WorkflowActivityAttachment
	if err := r.db.First(&att, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &att, nil
}

// ─── Audit ───────────────────────────────────────────────────────

func (r *WorkflowRepository) ListAuditLogs(wfID uuid.UUID) ([]models.WorkflowAuditLog, error) {
	var logs []models.WorkflowAuditLog
	err := r.db.Where("workflow_id = ?", wfID).
		Preload("Actor").
		Order("created_at DESC").
		Find(&logs).Error
	return logs, err
}

// ─── Helpers ─────────────────────────────────────────────────────

func (r *WorkflowRepository) checkAutoComplete(wfID uuid.UUID, actorID uuid.UUID) {
	var total, done int64
	r.db.Model(&models.WorkflowActivity{}).Where("workflow_id = ?", wfID).Count(&total)
	r.db.Model(&models.WorkflowActivity{}).Where("workflow_id = ? AND status IN (?, ?)", wfID, models.ActivityCompleted, models.ActivitySkipped).Count(&done)

	if total > 0 && total == done {
		now := time.Now()
		r.db.Model(&models.Workflow{}).Where("id = ? AND status != ?", wfID, models.WorkflowCompleted).
			Updates(map[string]interface{}{"status": models.WorkflowCompleted, "completed_at": &now})
		r.logAudit(wfID, nil, actorID, "STATUS_CHANGED", "ACTIVE", "COMPLETED", "All activities completed — workflow auto-completed")
	}
}

func (r *WorkflowRepository) logAudit(wfID uuid.UUID, actID *uuid.UUID, actorID uuid.UUID, action, oldVal, newVal, desc string) {
	log := &models.WorkflowAuditLog{
		WorkflowID:  wfID,
		ActivityID:  actID,
		ActorID:     actorID,
		Action:      action,
		OldValue:    oldVal,
		NewValue:    newVal,
		Description: desc,
	}
	r.db.Create(log) // best-effort
}
