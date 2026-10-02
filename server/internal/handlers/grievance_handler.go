package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
	"aangan/internal/services"
)

type GrievanceHandler struct {
	repo      *repositories.GrievanceRepository
	notifRepo *repositories.NotificationRepository
	notifier  *services.Notifier
}

func NewGrievanceHandler(repo *repositories.GrievanceRepository, notifRepo *repositories.NotificationRepository, notifier *services.Notifier) *GrievanceHandler {
	return &GrievanceHandler{repo: repo, notifRepo: notifRepo, notifier: notifier}
}

type createGrievanceReq struct {
	Title         string                   `json:"title" binding:"required,max=200"`
	TitleMr       string                   `json:"titleMr,omitempty"`
	Description   string                   `json:"description" binding:"required"`
	DescriptionMr string                   `json:"descriptionMr,omitempty"`
	Category      models.GrievanceCategory `json:"category" binding:"required"`
	Priority      models.GrievancePriority `json:"priority,omitempty"`
	Type          models.GrievanceType     `json:"type,omitempty"`
}

// Create a new grievance. Row ownership is set by the repo from ActorContext.
func (h *GrievanceHandler) Create(c *gin.Context) {
	var req createGrievanceReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}

	actor := middleware.GetActor(c)
	g := &models.Grievance{
		Title:         req.Title,
		TitleMr:       req.TitleMr,
		Description:   req.Description,
		DescriptionMr: req.DescriptionMr,
		Category:      req.Category,
		Priority:      req.Priority,
		Type:          req.Type,
	}
	if g.Priority == "" {
		g.Priority = models.PriorityMedium
	}

	if err := h.repo.Create(actor, g); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "CREATE_FAILED"})
		return
	}

	// Notify raiser + all admins
	go h.notifier.GrievanceCreated(actor.MemberID, g.TicketNo, g.Title, g.ID)

	c.JSON(http.StatusCreated, g)
}

// List returns grievances visible to the actor (own for members, all for admin).
func (h *GrievanceHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)

	var status *models.GrievanceStatus
	if s := c.Query("status"); s != "" {
		gs := models.GrievanceStatus(s)
		status = &gs
	}

	var category *models.GrievanceCategory
	if cat := c.Query("category"); cat != "" {
		gc := models.GrievanceCategory(cat)
		category = &gc
	}

	var gType *models.GrievanceType
	if t := c.Query("type"); t != "" {
		gt := models.GrievanceType(t)
		gType = &gt
	}

	rows, err := h.repo.List(actor, status, category, gType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"grievances": rows, "count": len(rows)})
}

// GetByID returns one grievance, enforcing row-level ACL.
func (h *GrievanceHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	g, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, g)
}

type updateStatusReq struct {
	Status     models.GrievanceStatus `json:"status" binding:"required"`
	Resolution string                 `json:"resolution,omitempty"`
}

// UpdateStatus moves a grievance through its state machine.
func (h *GrievanceHandler) UpdateStatus(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req updateStatusReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)

	// Fetch grievance before update to get raiser info
	g, _ := h.repo.GetByID(actor, id)

	if err := h.repo.UpdateStatus(actor, id, req.Status, req.Resolution); err != nil {
		writeRepoError(c, err)
		return
	}

	// Notify the raiser about status change
	if g != nil {
		go h.notifier.GrievanceStatusChanged(g.RaisedByMemberID, g.TicketNo, string(req.Status), id)
	}

	c.JSON(http.StatusOK, gin.H{"message": "Status updated"})
}

type addCommentReq struct {
	Comment    string `json:"comment" binding:"required"`
	IsInternal bool   `json:"isInternal,omitempty"`
}

// AddComment appends a comment to a grievance.
func (h *GrievanceHandler) AddComment(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req addCommentReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	comment, err := h.repo.AddComment(actor, id, req.Comment, req.IsInternal)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, comment)
}

// Stats returns counts of grievances grouped by status.
func (h *GrievanceHandler) Stats(c *gin.Context) {
	stats, err := h.repo.Stats()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "STATS_FAILED"})
		return
	}
	c.JSON(http.StatusOK, stats)
}

type grievanceAssignReq struct {
	AssigneeID string `json:"assigneeId" binding:"required"`
}

// Assign sets the committee member handling a grievance. Admin only.
func (h *GrievanceHandler) Assign(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req grievanceAssignReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	assigneeID, err := uuid.Parse(req.AssigneeID)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid assignee ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Assign(actor, id, assigneeID); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Grievance assigned"})
}

// writeRepoError maps repository errors to HTTP responses.
func writeRepoError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, repositories.ErrForbidden):
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: err.Error(), Code: "FORBIDDEN"})
	case errors.Is(err, repositories.ErrNotFound):
		c.JSON(http.StatusNotFound, response.ErrorResponse{Error: err.Error(), Code: "NOT_FOUND"})
	default:
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "INTERNAL_ERROR"})
	}
}
