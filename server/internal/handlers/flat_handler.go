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

type FlatHandler struct {
	repo *repositories.FlatRepository
}

func NewFlatHandler(repo *repositories.FlatRepository) *FlatHandler {
	return &FlatHandler{repo: repo}
}

type createFlatReq struct {
	FlatNumber   string     `json:"flatNumber" binding:"required"`
	WingID       *uuid.UUID `json:"wingId,omitempty"`
	Floor        int        `json:"floor" binding:"required"`
	AreaSqft     float64    `json:"areaSqft,omitempty"`
	OwnerName    string     `json:"ownerName,omitempty"`
	ShareCertNo  string     `json:"shareCertNo,omitempty"`
	NomineeName  string     `json:"nomineeName,omitempty"`
	PurchaseDate *time.Time `json:"purchaseDate,omitempty"`
}

func (h *FlatHandler) Create(c *gin.Context) {
	var req createFlatReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	f := &models.Flat{
		FlatNumber: req.FlatNumber, WingID: req.WingID, Floor: req.Floor,
		AreaSqft: req.AreaSqft, OwnerName: req.OwnerName,
		ShareCertNo: req.ShareCertNo, NomineeName: req.NomineeName,
		PurchaseDate: req.PurchaseDate,
	}
	if err := h.repo.Create(actor, f); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, f)
}

func (h *FlatHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	var wingFilter *uuid.UUID
	if s := c.Query("wingId"); s != "" {
		if id, err := uuid.Parse(s); err == nil {
			wingFilter = &id
		}
	}
	rows, err := h.repo.List(actor, wingFilter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"flats": rows, "count": len(rows)})
}

func (h *FlatHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	f, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, f)
}

func (h *FlatHandler) Update(c *gin.Context) {
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

func (h *FlatHandler) ListWings(c *gin.Context) {
	rows, err := h.repo.ListWings()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"wings": rows, "count": len(rows)})
}
