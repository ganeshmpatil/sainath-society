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

type SuggestionHandler struct {
	repo *repositories.SuggestionRepository
}

func NewSuggestionHandler(repo *repositories.SuggestionRepository) *SuggestionHandler {
	return &SuggestionHandler{repo: repo}
}

type createSuggestionReq struct {
	Title         string `json:"title" binding:"required"`
	TitleMr       string `json:"titleMr,omitempty"`
	Description   string `json:"description" binding:"required"`
	DescriptionMr string `json:"descriptionMr,omitempty"`
	Category      string `json:"category,omitempty"`
}

func (h *SuggestionHandler) Create(c *gin.Context) {
	var req createSuggestionReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	s := &models.Suggestion{
		Title: req.Title, TitleMr: req.TitleMr,
		Description: req.Description, DescriptionMr: req.DescriptionMr,
		Category: req.Category,
	}
	if err := h.repo.Create(actor, s); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, s)
}

func (h *SuggestionHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor, c.Query("sortBy"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"suggestions": rows, "count": len(rows)})
}

func (h *SuggestionHandler) GetByID(c *gin.Context) {
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

func (h *SuggestionHandler) Upvote(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Upvote(actor, id); err != nil {
		if errors.Is(err, repositories.ErrAlreadyUpvoted) {
			c.JSON(http.StatusConflict, response.ErrorResponse{Error: err.Error(), Code: "ALREADY_UPVOTED"})
			return
		}
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Upvoted"})
}

type respondSuggestionReq struct {
	Status      models.SuggestionStatus `json:"status" binding:"required"`
	Response    string                  `json:"response,omitempty"`
	ResponseMr  string                  `json:"responseMr,omitempty"`
}

func (h *SuggestionHandler) Respond(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req respondSuggestionReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Respond(actor, id, req.Status, req.Response, req.ResponseMr); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Response recorded"})
}
