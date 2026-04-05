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

type EventHandler struct {
	repo *repositories.EventRepository
}

func NewEventHandler(repo *repositories.EventRepository) *EventHandler {
	return &EventHandler{repo: repo}
}

type createEventReq struct {
	Title         string           `json:"title" binding:"required,max=200"`
	TitleMr       string           `json:"titleMr,omitempty"`
	Description   string           `json:"description,omitempty"`
	DescriptionMr string           `json:"descriptionMr,omitempty"`
	EventType     models.EventType `json:"eventType" binding:"required"`
	StartTime     time.Time        `json:"startTime" binding:"required"`
	EndTime       time.Time        `json:"endTime" binding:"required"`
	Location      string           `json:"location,omitempty"`
	IsRSVPRequired bool            `json:"isRsvpRequired,omitempty"`
}

func (h *EventHandler) Create(c *gin.Context) {
	var req createEventReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	e := &models.Event{
		Title: req.Title, TitleMr: req.TitleMr,
		Description: req.Description, DescriptionMr: req.DescriptionMr,
		EventType: req.EventType, StartTime: req.StartTime, EndTime: req.EndTime,
		Location: req.Location, IsRSVPRequired: req.IsRSVPRequired,
		Status: models.EventScheduled,
	}
	if err := h.repo.Create(actor, e); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, e)
}

func (h *EventHandler) ListUpcoming(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListUpcoming(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"events": rows, "count": len(rows)})
}

func (h *EventHandler) ListAll(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListAll(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"events": rows, "count": len(rows)})
}

func (h *EventHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	e, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, e)
}

type rsvpReq struct {
	Status     models.RSVPStatus `json:"status" binding:"required"`
	GuestCount int               `json:"guestCount,omitempty"`
}

func (h *EventHandler) RSVP(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req rsvpReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.RSVP(actor, id, req.Status, req.GuestCount); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "RSVP recorded"})
}
