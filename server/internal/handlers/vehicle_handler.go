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

type VehicleHandler struct {
	repo *repositories.VehicleRepository
}

func NewVehicleHandler(repo *repositories.VehicleRepository) *VehicleHandler {
	return &VehicleHandler{repo: repo}
}

type createVehicleReq struct {
	RegistrationNo  string             `json:"registrationNo" binding:"required,max=20"`
	VehicleType     models.VehicleType `json:"vehicleType" binding:"required"`
	Make            string             `json:"make,omitempty"`
	Model           string             `json:"model,omitempty"`
	Color           string             `json:"color,omitempty"`
	ParkingSlot     string             `json:"parkingSlot,omitempty"`
	StickerNo       string             `json:"stickerNo,omitempty"`
}

// Register a vehicle. Repo forces OwnerMemberID from the actor unless admin.
func (h *VehicleHandler) Create(c *gin.Context) {
	var req createVehicleReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	v := &models.Vehicle{
		RegistrationNo: req.RegistrationNo,
		VehicleType:    req.VehicleType,
		Make:           req.Make,
		Model:          req.Model,
		Color:          req.Color,
		ParkingSlot:    req.ParkingSlot,
		StickerNo:      req.StickerNo,
		IsActive:       true,
	}
	if err := h.repo.Create(actor, v); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, v)
}

func (h *VehicleHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"vehicles": rows, "count": len(rows)})
}

func (h *VehicleHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	v, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, v)
}

func (h *VehicleHandler) Update(c *gin.Context) {
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

func (h *VehicleHandler) Delete(c *gin.Context) {
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
