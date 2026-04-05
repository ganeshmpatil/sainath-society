package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type GrievanceHandler struct {
	repo     *repositories.GrievanceRepository
	notifRepo *repositories.NotificationRepository
}

func NewGrievanceHandler(repo *repositories.GrievanceRepository, notifRepo *repositories.NotificationRepository) *GrievanceHandler {
	return &GrievanceHandler{repo: repo, notifRepo: notifRepo}
}

type createGrievanceReq struct {
	Title         string                    `json:"title" binding:"required,max=200"`
	TitleMr       string                    `json:"titleMr,omitempty"`
	Description   string                    `json:"description" binding:"required"`
	DescriptionMr string                    `json:"descriptionMr,omitempty"`
	Category      models.GrievanceCategory  `json:"category" binding:"required"`
	Priority      models.GrievancePriority  `json:"priority,omitempty"`
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
	}
	if g.Priority == "" {
		g.Priority = models.PriorityMedium
	}

	if err := h.repo.Create(actor, g); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "CREATE_FAILED"})
		return
	}

	// Fire-and-forget notification to the member (WhatsApp/in-app).
	_ = h.notifRepo.Enqueue(&models.Notification{
		RecipientID:  actor.MemberID,
		Channel:      models.ChannelWhatsApp,
		Subject:      "तक्रार नोंदवली",
		Body:         "आपली तक्रार क्रमांक " + g.TicketNo + " यशस्वीरित्या नोंदवली गेली आहे.",
		BodyMr:       "आपली तक्रार क्रमांक " + g.TicketNo + " यशस्वीरित्या नोंदवली गेली आहे.",
		Language:     "mr",
		EventType:    "GRIEVANCE_CREATED",
		ResourceType: "grievance",
		ResourceID:   &g.ID,
	})

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

	rows, err := h.repo.List(actor, status)
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
	if err := h.repo.UpdateStatus(actor, id, req.Status, req.Resolution); err != nil {
		writeRepoError(c, err)
		return
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
	if err := h.repo.AddComment(actor, id, req.Comment, req.IsInternal); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, gin.H{"message": "Comment added"})
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
