package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type HallBookingHandler struct {
	repo *repositories.HallBookingRepository
}

func NewHallBookingHandler(repo *repositories.HallBookingRepository) *HallBookingHandler {
	return &HallBookingHandler{repo: repo}
}

type createHallBookingReq struct {
	Purpose        string    `json:"purpose" binding:"required"`
	PurposeMr      string    `json:"purposeMr,omitempty"`
	EventType      string    `json:"eventType,omitempty"`
	ExpectedGuests int       `json:"expectedGuests,omitempty"`
	StartTime      time.Time `json:"startTime" binding:"required"`
	EndTime        time.Time `json:"endTime" binding:"required"`
	BookingCharge  float64   `json:"bookingCharge,omitempty"`
	Deposit        float64   `json:"deposit,omitempty"`
}

func (h *HallBookingHandler) Create(c *gin.Context) {
	var req createHallBookingReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	b := &models.HallBooking{
		Purpose: req.Purpose, PurposeMr: req.PurposeMr,
		EventType: req.EventType, ExpectedGuests: req.ExpectedGuests,
		StartTime: req.StartTime, EndTime: req.EndTime,
		BookingCharge: req.BookingCharge, Deposit: req.Deposit,
	}
	if err := h.repo.Create(actor, b); err != nil {
		if errors.Is(err, repositories.ErrSlotUnavailable) {
			c.JSON(http.StatusConflict, response.ErrorResponse{Error: err.Error(), Code: "SLOT_UNAVAILABLE"})
			return
		}
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, b)
}

func (h *HallBookingHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListForActor(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"bookings": rows, "count": len(rows)})
}

func (h *HallBookingHandler) CheckAvailability(c *gin.Context) {
	startStr := c.Query("start")
	endStr := c.Query("end")
	start, err1 := time.Parse(time.RFC3339, startStr)
	end, err2 := time.Parse(time.RFC3339, endStr)
	if err1 != nil || err2 != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "start and end required (RFC3339)", Code: "INVALID_REQUEST"})
		return
	}
	available, err := h.repo.CheckAvailability(start, end)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "CHECK_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"available": available, "start": start, "end": end})
}

func (h *HallBookingHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	b, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, b)
}

type decideBookingReq struct {
	Approve bool   `json:"approve"`
	Reason  string `json:"reason,omitempty"`
}

func (h *HallBookingHandler) Decide(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req decideBookingReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Decide(actor, id, req.Approve, req.Reason); err != nil {
		if errors.Is(err, repositories.ErrSlotUnavailable) {
			c.JSON(http.StatusConflict, response.ErrorResponse{Error: err.Error(), Code: "SLOT_UNAVAILABLE"})
			return
		}
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Decision recorded"})
}

func (h *HallBookingHandler) Cancel(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Cancel(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Cancelled"})
}
