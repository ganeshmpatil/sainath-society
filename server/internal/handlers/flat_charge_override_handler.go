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

type FlatChargeOverrideHandler struct {
	repo *repositories.FlatChargeOverrideRepository
}

func NewFlatChargeOverrideHandler(repo *repositories.FlatChargeOverrideRepository) *FlatChargeOverrideHandler {
	return &FlatChargeOverrideHandler{repo: repo}
}

func (h *FlatChargeOverrideHandler) ListAll(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListAll(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"overrides": rows, "count": len(rows)})
}

func (h *FlatChargeOverrideHandler) ListForFlat(c *gin.Context) {
	flatID, err := uuid.Parse(c.Param("flatId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid flat ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListForFlat(actor, flatID)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"overrides": rows})
}

type upsertOverrideReq struct {
	FlatID       uuid.UUID `json:"flatId" binding:"required"`
	ChargeHeadID uuid.UUID `json:"chargeHeadId" binding:"required"`
	Rate         float64   `json:"rate"`
	Exempt       bool      `json:"exempt"`
	Reason       string    `json:"reason"`
}

func (h *FlatChargeOverrideHandler) Upsert(c *gin.Context) {
	var req upsertOverrideReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	o := &models.FlatChargeOverride{
		FlatID:       req.FlatID,
		ChargeHeadID: req.ChargeHeadID,
		Rate:         req.Rate,
		Exempt:       req.Exempt,
		Reason:       req.Reason,
	}
	if err := h.repo.Upsert(actor, o); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Override saved"})
}

func (h *FlatChargeOverrideHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Delete(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Override removed"})
}
