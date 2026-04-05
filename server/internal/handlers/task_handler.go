package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type TaskHandler struct {
	repo *repositories.TaskRepository
}

func NewTaskHandler(repo *repositories.TaskRepository) *TaskHandler {
	return &TaskHandler{repo: repo}
}

type createTaskReq struct {
	Title         string              `json:"title" binding:"required,max=300"`
	TitleMr       string              `json:"titleMr,omitempty"`
	Description   string              `json:"description,omitempty"`
	DescriptionMr string              `json:"descriptionMr,omitempty"`
	OwnerMemberID *uuid.UUID          `json:"ownerMemberId,omitempty"` // admin-only
	Priority      models.TaskPriority `json:"priority,omitempty"`
	DueDate       *time.Time          `json:"dueDate,omitempty"`
}

// Create a new task. Members can only create self-tasks; admins can assign
// to any member.
func (h *TaskHandler) Create(c *gin.Context) {
	var req createTaskReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)

	t := &models.Task{
		Title:         req.Title,
		TitleMr:       req.TitleMr,
		Description:   req.Description,
		DescriptionMr: req.DescriptionMr,
		Priority:      req.Priority,
		DueDate:       req.DueDate,
		Source:        models.TaskSourceManual,
	}
	if t.Priority == "" {
		t.Priority = models.TaskPriorityMedium
	}
	if actor.IsAdmin() && req.OwnerMemberID != nil {
		t.OwnerMemberID = *req.OwnerMemberID
	}

	if err := h.repo.Create(actor, t); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, t)
}

// ListPending returns pending tasks for the actor (or any owner if admin).
func (h *TaskHandler) ListPending(c *gin.Context) {
	actor := middleware.GetActor(c)

	var ownerFilter *uuid.UUID
	if ownerStr := c.Query("ownerMemberId"); ownerStr != "" && actor.IsAdmin() {
		if id, err := uuid.Parse(ownerStr); err == nil {
			ownerFilter = &id
		}
	}

	rows, err := h.repo.ListPending(actor, ownerFilter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"tasks": rows, "count": len(rows)})
}

// GetByID returns one task (ACL enforced).
func (h *TaskHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	t, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, t)
}

type updateTaskStatusReq struct {
	Status models.TaskStatus `json:"status" binding:"required"`
}

// UpdateStatus lets the owner (or admin) transition task status.
func (h *TaskHandler) UpdateStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req updateTaskStatusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.UpdateStatus(actor, id, req.Status); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Status updated"})
}
