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

type NoticeHandler struct {
	repo *repositories.NoticeRepository
}

func NewNoticeHandler(repo *repositories.NoticeRepository) *NoticeHandler {
	return &NoticeHandler{repo: repo}
}

type createNoticeReq struct {
	Title    string                `json:"title" binding:"required,max=200"`
	TitleMr  string                `json:"titleMr,omitempty"`
	Body     string                `json:"body" binding:"required"`
	BodyMr   string                `json:"bodyMr,omitempty"`
	Category models.NoticeCategory `json:"category,omitempty"`
	IsPinned bool                  `json:"isPinned,omitempty"`
}

func (h *NoticeHandler) Create(c *gin.Context) {
	var req createNoticeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	n := &models.Notice{
		Title: req.Title, TitleMr: req.TitleMr,
		Body: req.Body, BodyMr: req.BodyMr,
		Category: req.Category, IsPinned: req.IsPinned,
		IsPublished: true,
	}
	if n.Category == "" {
		n.Category = models.NoticeGeneral
	}
	if err := h.repo.Create(actor, n); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, n)
}

func (h *NoticeHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"notices": rows, "count": len(rows)})
}

func (h *NoticeHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	n, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, n)
}

func (h *NoticeHandler) Update(c *gin.Context) {
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

func (h *NoticeHandler) Delete(c *gin.Context) {
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
