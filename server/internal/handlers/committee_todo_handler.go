package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
	"aangan/internal/services"
)

type CommitteeTodoHandler struct {
	repo     *repositories.CommitteeTodoRepository
	notifier *services.Notifier
}

func NewCommitteeTodoHandler(repo *repositories.CommitteeTodoRepository, notifier *services.Notifier) *CommitteeTodoHandler {
	return &CommitteeTodoHandler{repo: repo, notifier: notifier}
}

type createCommitteeTodoReq struct {
	Title              string              `json:"title" binding:"required,max=300"`
	TitleMr            string              `json:"titleMr,omitempty"`
	Description        string              `json:"description,omitempty"`
	DescriptionMr      string              `json:"descriptionMr,omitempty"`
	Category           models.TodoCategory `json:"category" binding:"required"`
	Priority           models.TodoPriority `json:"priority" binding:"required"`
	DueDate            string              `json:"dueDate" binding:"required"`
	Notes              string              `json:"notes,omitempty"`
	NotesMr            string              `json:"notesMr,omitempty"`
	AssignedToMemberID *string             `json:"assignedToMemberId,omitempty"`
}

func (h *CommitteeTodoHandler) Create(c *gin.Context) {
	var req createCommitteeTodoReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}

	dueDate, err := time.Parse(time.RFC3339, req.DueDate)
	if err != nil {
		// Try date-only format
		dueDate, err = time.Parse("2006-01-02", req.DueDate)
		if err != nil {
			c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid dueDate format. Use YYYY-MM-DD or RFC3339.", Code: "INVALID_DATE"})
			return
		}
	}

	actor := middleware.GetActor(c)
	ct := &models.CommitteeTodo{
		Title:         req.Title,
		TitleMr:       req.TitleMr,
		Description:   req.Description,
		DescriptionMr: req.DescriptionMr,
		Category:      req.Category,
		Priority:      req.Priority,
		Status:        models.TodoPending,
		DueDate:       dueDate,
		Notes:         req.Notes,
		NotesMr:       req.NotesMr,
		IsActive:      true,
	}

	if req.AssignedToMemberID != nil && *req.AssignedToMemberID != "" {
		uid, err := uuid.Parse(*req.AssignedToMemberID)
		if err == nil {
			ct.AssignedToMemberID = &uid
		}
	}

	if err := h.repo.Create(actor, ct); err != nil {
		writeRepoError(c, err)
		return
	}

	// Notify committee members about the new todo
	go h.notifier.NotifyAdmins(
		"New Committee Task: "+ct.Title,
		fmt.Sprintf("A new committee task \"%s\" (Category: %s) has been added with due date %s.", ct.Title, ct.Category, ct.DueDate.Format("02 Jan 2006")),
		fmt.Sprintf("नवीन समिती कार्य \"%s\" (प्रवर्ग: %s) %s या तारखेसाठी जोडले आहे.", ct.Title, ct.Category, ct.DueDate.Format("02 Jan 2006")),
		"COMMITTEE_TODO_CREATED", "committee_todo", &ct.ID,
	)

	c.JSON(http.StatusCreated, ct)
}

func (h *CommitteeTodoHandler) List(c *gin.Context) {
	yearStr := c.Query("year")
	monthStr := c.Query("month")

	if yearStr != "" && monthStr != "" {
		year, err1 := strconv.Atoi(yearStr)
		month, err2 := strconv.Atoi(monthStr)
		if err1 != nil || err2 != nil || month < 1 || month > 12 {
			c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid year or month", Code: "INVALID_PARAMS"})
			return
		}
		rows, err := h.repo.ListByMonth(year, month)
		if err != nil {
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"todos": rows, "count": len(rows)})
		return
	}

	rows, err := h.repo.ListAll()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"todos": rows, "count": len(rows)})
}

func (h *CommitteeTodoHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	ct, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, ct)
}

func (h *CommitteeTodoHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var patch map[string]interface{}
	if err := c.ShouldBindJSON(&patch); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Update(actor, id, patch); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Updated"})
}

type updateTodoStatusReq struct {
	Status models.TodoStatus `json:"status" binding:"required"`
}

func (h *CommitteeTodoHandler) UpdateStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req updateTodoStatusReq
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

func (h *CommitteeTodoHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Delete(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Deleted"})
}
