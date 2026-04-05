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

type ParkingHandler struct {
	repo *repositories.ParkingRepository
}

func NewParkingHandler(repo *repositories.ParkingRepository) *ParkingHandler {
	return &ParkingHandler{repo: repo}
}

type createSlotReq struct {
	SlotNumber string                 `json:"slotNumber" binding:"required"`
	SlotType   models.ParkingSlotType `json:"slotType" binding:"required"`
	Location   string                 `json:"location,omitempty"`
}

func (h *ParkingHandler) Create(c *gin.Context) {
	var req createSlotReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	slot := &models.ParkingSlot{
		SlotNumber: req.SlotNumber, SlotType: req.SlotType, Location: req.Location,
	}
	if err := h.repo.Create(actor, slot); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, slot)
}

func (h *ParkingHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"slots": rows, "count": len(rows)})
}

type allocateSlotReq struct {
	FlatID   uuid.UUID `json:"flatId" binding:"required"`
	MemberID uuid.UUID `json:"memberId" binding:"required"`
}

func (h *ParkingHandler) Allocate(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req allocateSlotReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Allocate(actor, id, req.FlatID, req.MemberID); err != nil {
		if errors.Is(err, repositories.ErrSlotAlreadyAllocated) {
			c.JSON(http.StatusConflict, response.ErrorResponse{Error: err.Error(), Code: "SLOT_ALLOCATED"})
			return
		}
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Slot allocated"})
}

func (h *ParkingHandler) Release(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Release(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Slot released"})
}

func (h *ParkingHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	s, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, s)
}
