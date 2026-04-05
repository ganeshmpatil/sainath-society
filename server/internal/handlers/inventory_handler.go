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

type InventoryHandler struct {
	repo *repositories.InventoryRepository
}

func NewInventoryHandler(repo *repositories.InventoryRepository) *InventoryHandler {
	return &InventoryHandler{repo: repo}
}

type createInventoryReq struct {
	Name          string               `json:"name" binding:"required"`
	NameMr        string               `json:"nameMr,omitempty"`
	Category      string               `json:"category" binding:"required"`
	Description   string               `json:"description,omitempty"`
	DescriptionMr string               `json:"descriptionMr,omitempty"`
	Quantity      int                  `json:"quantity,omitempty"`
	UnitPrice     float64              `json:"unitPrice,omitempty"`
	Condition     models.ItemCondition `json:"condition,omitempty"`
	Location      string               `json:"location,omitempty"`
	SerialNo      string               `json:"serialNo,omitempty"`
}

func (h *InventoryHandler) Create(c *gin.Context) {
	var req createInventoryReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	item := &models.InventoryItem{
		Name: req.Name, NameMr: req.NameMr, Category: req.Category,
		Description: req.Description, DescriptionMr: req.DescriptionMr,
		Quantity: req.Quantity, UnitPrice: req.UnitPrice,
		Condition: req.Condition, Location: req.Location, SerialNo: req.SerialNo,
	}
	if item.Quantity == 0 {
		item.Quantity = 1
	}
	if item.Condition == "" {
		item.Condition = models.ConditionGood
	}
	if err := h.repo.Create(actor, item); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, item)
}

func (h *InventoryHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor, c.Query("category"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"items": rows, "count": len(rows)})
}

func (h *InventoryHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	item, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, item)
}

func (h *InventoryHandler) Update(c *gin.Context) {
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

func (h *InventoryHandler) Delete(c *gin.Context) {
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
