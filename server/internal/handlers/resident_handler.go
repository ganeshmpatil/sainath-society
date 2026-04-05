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

type ResidentHandler struct {
	repo *repositories.MemberRepository
}

func NewResidentHandler(repo *repositories.MemberRepository) *ResidentHandler {
	return &ResidentHandler{repo: repo}
}

type createResidentReq struct {
	Name        string      `json:"name" binding:"required"`
	Mobile      string      `json:"mobile" binding:"required"`
	FlatID      *uuid.UUID  `json:"flatId,omitempty"`
	Role        models.Role `json:"role,omitempty"`
	Designation string      `json:"designation,omitempty"`
}

func (h *ResidentHandler) Create(c *gin.Context) {
	var req createResidentReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	m := &models.Member{
		Name: req.Name, Mobile: req.Mobile, FlatID: req.FlatID,
		Role: req.Role, Designation: req.Designation,
	}
	if m.Role == "" {
		m.Role = models.RoleMember
	}
	if err := h.repo.Create(actor, m); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, m)
}

func (h *ResidentHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	var roleFilter *models.Role
	if s := c.Query("role"); s != "" {
		r := models.Role(s)
		roleFilter = &r
	}
	onlyActive := c.Query("activeOnly") == "true"
	rows, err := h.repo.List(actor, roleFilter, onlyActive)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"residents": rows, "count": len(rows)})
}

func (h *ResidentHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	m, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, m)
}

func (h *ResidentHandler) Update(c *gin.Context) {
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

func (h *ResidentHandler) Deactivate(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Deactivate(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Deactivated"})
}
