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

type DocumentHandler struct {
	repo *repositories.DocumentRepository
}

func NewDocumentHandler(repo *repositories.DocumentRepository) *DocumentHandler {
	return &DocumentHandler{repo: repo}
}

type createDocReq struct {
	Title         string                  `json:"title" binding:"required,max=200"`
	TitleMr       string                  `json:"titleMr,omitempty"`
	Description   string                  `json:"description,omitempty"`
	DescriptionMr string                  `json:"descriptionMr,omitempty"`
	Category      models.DocumentCategory `json:"category" binding:"required"`
	Scope         models.DocumentScope    `json:"scope,omitempty"`
	FileURL       string                  `json:"fileUrl" binding:"required"`
	FileName      string                  `json:"fileName" binding:"required"`
	FileSize      int64                   `json:"fileSize,omitempty"`
	MimeType      string                  `json:"mimeType,omitempty"`
	Checksum      string                  `json:"checksum,omitempty"`
	Tags          string                  `json:"tags,omitempty"`
	Confidential  bool                    `json:"confidential,omitempty"`
	EffectiveFrom *time.Time              `json:"effectiveFrom,omitempty"`
	ExpiresAt     *time.Time              `json:"expiresAt,omitempty"`
}

func (h *DocumentHandler) Create(c *gin.Context) {
	var req createDocReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	d := &models.Document{
		Title: req.Title, TitleMr: req.TitleMr,
		Description: req.Description, DescriptionMr: req.DescriptionMr,
		Category: req.Category, Scope: req.Scope,
		FileURL: req.FileURL, FileName: req.FileName, FileSize: req.FileSize,
		MimeType: req.MimeType, Checksum: req.Checksum,
		Tags: req.Tags, Confidential: req.Confidential,
		EffectiveFrom: req.EffectiveFrom, ExpiresAt: req.ExpiresAt,
		Version: 1, IsLatest: true,
	}
	if d.Scope == "" {
		d.Scope = models.DocScopePublic
	}
	if err := h.repo.Create(actor, d); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, d)
}

func (h *DocumentHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	var category *models.DocumentCategory
	if s := c.Query("category"); s != "" {
		cat := models.DocumentCategory(s)
		category = &cat
	}
	rows, err := h.repo.ListForActor(actor, category)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"documents": rows, "count": len(rows)})
}

func (h *DocumentHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	d, err := h.repo.GetByID(actor, id, c.ClientIP())
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, d)
}

type grantAccessReq struct {
	MemberID uuid.UUID `json:"memberId" binding:"required"`
	CanEdit  bool      `json:"canEdit,omitempty"`
}

func (h *DocumentHandler) Grant(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req grantAccessReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Grant(actor, id, req.MemberID, req.CanEdit); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Access granted"})
}

func (h *DocumentHandler) Archive(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Archive(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Archived"})
}
