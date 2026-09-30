package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type BudgetRepository struct {
	db *gorm.DB
}

func NewBudgetRepository(db *gorm.DB) *BudgetRepository {
	return &BudgetRepository{db: db}
}

// List returns all budgets ordered by financial year descending.
func (r *BudgetRepository) List(actor *ActorContext) ([]models.Budget, error) {
	var rows []models.Budget
	return rows, r.db.Order("financial_year DESC").Find(&rows).Error
}

// GetByID returns a budget with its line items preloaded.
func (r *BudgetRepository) GetByID(id uuid.UUID) (*models.Budget, error) {
	var b models.Budget
	if err := r.db.Preload("LineItems", func(db *gorm.DB) *gorm.DB {
		return db.Order("sort_order ASC, category ASC")
	}).First(&b, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &b, nil
}

// Create adds a new budget. Admin only.
func (r *BudgetRepository) Create(actor *ActorContext, b *models.Budget) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	b.CreatedByID = actor.MemberID
	return r.db.Create(b).Error
}

// Update modifies a budget. Admin only.
func (r *BudgetRepository) Update(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.Budget{}).Where("id = ?", id).Updates(updates)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// Delete removes a budget. Admin only, must be DRAFT status.
func (r *BudgetRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	var b models.Budget
	if err := r.db.First(&b, "id = ?", id).Error; err != nil {
		return ErrNotFound
	}
	if b.Status != models.BudgetDraft {
		return ErrForbidden
	}
	// Delete line items first, then budget
	r.db.Where("budget_id = ?", id).Delete(&models.BudgetLineItem{})
	return r.db.Delete(&b).Error
}

// AddLineItem adds a line item to a budget. Admin only.
func (r *BudgetRepository) AddLineItem(actor *ActorContext, item *models.BudgetLineItem) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Create(item).Error
}

// UpdateLineItem modifies a budget line item. Admin only.
func (r *BudgetRepository) UpdateLineItem(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.BudgetLineItem{}).Where("id = ?", id).Updates(updates)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// DeleteLineItem removes a budget line item. Admin only.
func (r *BudgetRepository) DeleteLineItem(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Where("id = ?", id).Delete(&models.BudgetLineItem{})
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// Approve sets the budget status and records the approver. Admin only.
func (r *BudgetRepository) Approve(actor *ActorContext, id uuid.UUID, status string) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	now := time.Now()
	updates := map[string]interface{}{
		"status":        status,
		"approved_by_id": actor.MemberID,
		"approved_at":   now,
	}
	// If setting to ACTIVE, deactivate any currently active budget first
	if status == string(models.BudgetActive) {
		r.db.Model(&models.Budget{}).
			Where("status = ?", models.BudgetActive).
			Updates(map[string]interface{}{"status": models.BudgetAGMApproved})
	}
	result := r.db.Model(&models.Budget{}).Where("id = ?", id).Updates(updates)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// GetActiveBudget returns the currently active budget with line items.
func (r *BudgetRepository) GetActiveBudget() (*models.Budget, error) {
	var b models.Budget
	if err := r.db.Preload("LineItems", func(db *gorm.DB) *gorm.DB {
		return db.Order("sort_order ASC, category ASC")
	}).Where("status = ?", models.BudgetActive).First(&b).Error; err != nil {
		return nil, err
	}
	return &b, nil
}

// UpdateActuals updates the actual_amount and computes variance for a line item.
func (r *BudgetRepository) UpdateActuals(budgetID uuid.UUID, headName string, actual float64) error {
	result := r.db.Model(&models.BudgetLineItem{}).
		Where("budget_id = ? AND head_name = ?", budgetID, headName).
		Updates(map[string]interface{}{
			"actual_amount": actual,
			"variance":      gorm.Expr("budgeted_amount - ?", actual),
		})
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}
