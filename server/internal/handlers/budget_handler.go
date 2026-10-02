package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type BudgetHandler struct {
	repo *repositories.BudgetRepository
}

func NewBudgetHandler(repo *repositories.BudgetRepository) *BudgetHandler {
	return &BudgetHandler{repo: repo}
}

// List returns all budgets.
func (h *BudgetHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"budgets": rows, "count": len(rows)})
}

// GetByID returns a single budget with line items.
func (h *BudgetHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	b, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, b)
}

type createBudgetReq struct {
	FinancialYear string  `json:"financialYear" binding:"required"`
	Title         string  `json:"title" binding:"required"`
	TotalIncome   float64 `json:"totalIncome"`
	TotalExpense  float64 `json:"totalExpense"`
	Surplus       float64 `json:"surplus"`
	Notes         string  `json:"notes"`
}

// Create adds a new budget.
func (h *BudgetHandler) Create(c *gin.Context) {
	var req createBudgetReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	b := &models.Budget{
		FinancialYear: req.FinancialYear,
		Title:         req.Title,
		Status:        models.BudgetDraft,
		TotalIncome:   req.TotalIncome,
		TotalExpense:  req.TotalExpense,
		Surplus:       req.Surplus,
		Notes:         req.Notes,
	}
	if err := h.repo.Create(actor, b); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, b)
}

// Update modifies a budget.
func (h *BudgetHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.Update(actor, id, updates); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Budget updated"})
}

// Delete removes a budget (DRAFT only).
func (h *BudgetHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.Delete(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Budget deleted"})
}

type addLineItemReq struct {
	Category       string  `json:"category" binding:"required"`   // INCOME or EXPENSE
	HeadName       string  `json:"headName" binding:"required"`
	HeadNameMr     string  `json:"headNameMr"`
	BudgetedAmount float64 `json:"budgetedAmount" binding:"required"`
	SortOrder      int     `json:"sortOrder"`
	Notes          string  `json:"notes"`
}

// AddLineItem adds a line item to a budget.
func (h *BudgetHandler) AddLineItem(c *gin.Context) {
	budgetID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req addLineItemReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	item := &models.BudgetLineItem{
		BudgetID:       budgetID,
		Category:       req.Category,
		HeadName:       req.HeadName,
		HeadNameMr:     req.HeadNameMr,
		BudgetedAmount: req.BudgetedAmount,
		SortOrder:      req.SortOrder,
		Notes:          req.Notes,
	}
	if err := h.repo.AddLineItem(actor, item); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, item)
}

// UpdateLineItem modifies a budget line item.
func (h *BudgetHandler) UpdateLineItem(c *gin.Context) {
	id, err := uuid.Parse(c.Param("itemId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.UpdateLineItem(actor, id, updates); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Line item updated"})
}

// DeleteLineItem removes a budget line item.
func (h *BudgetHandler) DeleteLineItem(c *gin.Context) {
	id, err := uuid.Parse(c.Param("itemId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.DeleteLineItem(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Line item deleted"})
}

type approveReq struct {
	Status string `json:"status" binding:"required"`
}

// Approve transitions the budget status and records the approver.
func (h *BudgetHandler) Approve(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req approveReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	// Validate status value
	switch req.Status {
	case "COMMITTEE_REVIEW", "AGM_APPROVED", "ACTIVE":
	default:
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid status. Must be COMMITTEE_REVIEW, AGM_APPROVED, or ACTIVE", Code: "INVALID_STATUS"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.Approve(actor, id, req.Status); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Budget status updated to " + req.Status})
}

// GetActive returns the currently active budget.
func (h *BudgetHandler) GetActive(c *gin.Context) {
	b, err := h.repo.GetActiveBudget()
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, b)
}

// BudgetVsActual returns line items with variance for comparison.
func (h *BudgetHandler) BudgetVsActual(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	b, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}

	var incomeItems, expenseItems []models.BudgetLineItem
	var totalBudgetedIncome, totalActualIncome float64
	var totalBudgetedExpense, totalActualExpense float64

	for _, item := range b.LineItems {
		switch item.Category {
		case "INCOME":
			incomeItems = append(incomeItems, item)
			totalBudgetedIncome += item.BudgetedAmount
			totalActualIncome += item.ActualAmount
		case "EXPENSE":
			expenseItems = append(expenseItems, item)
			totalBudgetedExpense += item.BudgetedAmount
			totalActualExpense += item.ActualAmount
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"budget":               b,
		"incomeItems":          incomeItems,
		"expenseItems":         expenseItems,
		"totalBudgetedIncome":  totalBudgetedIncome,
		"totalActualIncome":    totalActualIncome,
		"totalBudgetedExpense": totalBudgetedExpense,
		"totalActualExpense":   totalActualExpense,
		"budgetedSurplus":      totalBudgetedIncome - totalBudgetedExpense,
		"actualSurplus":        totalActualIncome - totalActualExpense,
	})
}
