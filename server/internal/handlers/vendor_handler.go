package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type VendorHandler struct {
	repo *repositories.VendorRepository
}

func NewVendorHandler(repo *repositories.VendorRepository) *VendorHandler {
	return &VendorHandler{repo: repo}
}

func (h *VendorHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"vendors": rows})
}

func (h *VendorHandler) GetByID(c *gin.Context) {
	actor := middleware.GetActor(c)
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID"})
		return
	}
	v, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, v)
}

func (h *VendorHandler) Create(c *gin.Context) {
	actor := middleware.GetActor(c)
	var v models.Vendor
	if err := c.ShouldBindJSON(&v); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.repo.Create(actor, &v); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, v)
}

func (h *VendorHandler) Update(c *gin.Context) {
	actor := middleware.GetActor(c)
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID"})
		return
	}
	var body map[string]interface{}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.repo.Update(actor, id, body); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Vendor updated"})
}

func (h *VendorHandler) Delete(c *gin.Context) {
	actor := middleware.GetActor(c)
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID"})
		return
	}
	if err := h.repo.Delete(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Vendor deactivated"})
}
