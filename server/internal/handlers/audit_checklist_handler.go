package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type AuditChecklistHandler struct {
	repo *repositories.AuditChecklistRepository
}

func NewAuditChecklistHandler(repo *repositories.AuditChecklistRepository) *AuditChecklistHandler {
	return &AuditChecklistHandler{repo: repo}
}

func (h *AuditChecklistHandler) List(c *gin.Context) {
	rows, err := h.repo.List()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"checklists": rows, "count": len(rows)})
}

func (h *AuditChecklistHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	row, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	progress, _ := h.repo.Progress(id)
	c.JSON(http.StatusOK, gin.H{
		"checklist": row,
		"items":     row.Items,
		"progress":  progress,
	})
}

type createAuditChecklistReq struct {
	FinancialYear string `json:"financialYear" binding:"required"`
	Title         string `json:"title" binding:"required"`
	AuditorName   string `json:"auditorName,omitempty"`
}

func (h *AuditChecklistHandler) Create(c *gin.Context) {
	var req createAuditChecklistReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	cl := &models.AuditChecklist{
		FinancialYear: req.FinancialYear,
		Title:         req.Title,
		AuditorName:   req.AuditorName,
		Status:        "IN_PROGRESS",
	}
	if err := h.repo.CreateWithDefaults(actor, cl); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, cl)
}

func (h *AuditChecklistHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var body map[string]interface{}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Update(actor, id, body); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Updated"})
}

type addAuditItemReq struct {
	Category    string `json:"category" binding:"required"`
	Title       string `json:"title" binding:"required"`
	TitleMr     string `json:"titleMr,omitempty"`
	Description string `json:"description,omitempty"`
}

func (h *AuditChecklistHandler) AddItem(c *gin.Context) {
	checklistID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req addAuditItemReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	item := &models.AuditChecklistItem{
		ChecklistID: checklistID,
		Category:    req.Category,
		Title:       req.Title,
		TitleMr:     req.TitleMr,
		Description: req.Description,
	}
	if err := h.repo.AddItem(actor, item); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, item)
}

func (h *AuditChecklistHandler) ToggleItem(c *gin.Context) {
	itemID, err := uuid.Parse(c.Param("itemId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var body struct {
		Completed bool `json:"completed"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.ToggleItem(actor, itemID, body.Completed); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Updated"})
}

func (h *AuditChecklistHandler) UpdateItemRemarks(c *gin.Context) {
	itemID, err := uuid.Parse(c.Param("itemId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var body struct {
		Remarks string `json:"remarks"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.UpdateItemRemarks(actor, itemID, body.Remarks); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Updated"})
}

func (h *AuditChecklistHandler) DeleteItem(c *gin.Context) {
	itemID, err := uuid.Parse(c.Param("itemId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.DeleteItem(actor, itemID); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Deleted"})
}

func (h *AuditChecklistHandler) Progress(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	progress, err := h.repo.Progress(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "PROGRESS_FAILED"})
		return
	}
	c.JSON(http.StatusOK, progress)
}
