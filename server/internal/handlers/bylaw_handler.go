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

type ByLawHandler struct {
	repo *repositories.ByLawRepository
}

func NewByLawHandler(repo *repositories.ByLawRepository) *ByLawHandler {
	return &ByLawHandler{repo: repo}
}

type createByLawReq struct {
	Section   string `json:"section" binding:"required"`
	Title     string `json:"title" binding:"required,max=300"`
	TitleMr   string `json:"titleMr,omitempty"`
	Content   string `json:"content" binding:"required"`
	ContentMr string `json:"contentMr,omitempty"`
	Category  string `json:"category,omitempty"`
}

func (h *ByLawHandler) Create(c *gin.Context) {
	var req createByLawReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	b := &models.ByLaw{
		Section: req.Section, Title: req.Title, TitleMr: req.TitleMr,
		Content: req.Content, ContentMr: req.ContentMr, Category: req.Category,
		IsActive: true,
	}
	if err := h.repo.Create(actor, b); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, b)
}

func (h *ByLawHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"bylaws": rows, "count": len(rows)})
}

func (h *ByLawHandler) GetByID(c *gin.Context) {
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

type amendByLawReq struct {
	NewContent string `json:"newContent" binding:"required"`
	Reason     string `json:"reason,omitempty"`
}

func (h *ByLawHandler) Amend(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req amendByLawReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Amend(actor, id, req.NewContent, req.Reason); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Amended"})
}
