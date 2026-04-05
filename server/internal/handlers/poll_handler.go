package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type PollHandler struct {
	repo *repositories.PollRepository
}

func NewPollHandler(repo *repositories.PollRepository) *PollHandler {
	return &PollHandler{repo: repo}
}

type pollOptionReq struct {
	OptionText   string `json:"optionText" binding:"required"`
	OptionTextMr string `json:"optionTextMr,omitempty"`
}

type createPollReq struct {
	Title         string          `json:"title" binding:"required"`
	TitleMr       string          `json:"titleMr,omitempty"`
	Description   string          `json:"description,omitempty"`
	DescriptionMr string          `json:"descriptionMr,omitempty"`
	StartsAt      time.Time       `json:"startsAt" binding:"required"`
	EndsAt        time.Time       `json:"endsAt" binding:"required"`
	IsAnonymous   bool            `json:"isAnonymous,omitempty"`
	Options       []pollOptionReq `json:"options" binding:"required,min=2"`
}

func (h *PollHandler) Create(c *gin.Context) {
	var req createPollReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	p := &models.Poll{
		Title: req.Title, TitleMr: req.TitleMr,
		Description: req.Description, DescriptionMr: req.DescriptionMr,
		Status: models.PollDraft,
		StartsAt: req.StartsAt, EndsAt: req.EndsAt,
		IsAnonymous: req.IsAnonymous,
	}
	opts := make([]models.PollOption, len(req.Options))
	for i, o := range req.Options {
		opts[i] = models.PollOption{OptionText: o.OptionText, OptionTextMr: o.OptionTextMr}
	}
	if err := h.repo.Create(actor, p, opts); err != nil {
		writeRepoError(c, err)
		return
	}
	p.Options = opts
	c.JSON(http.StatusCreated, p)
}

func (h *PollHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"polls": rows, "count": len(rows)})
}

func (h *PollHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	p, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, p)
}

func (h *PollHandler) Publish(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Publish(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Poll published"})
}

func (h *PollHandler) Close(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Close(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Poll closed"})
}

type voteReq struct {
	OptionID uuid.UUID `json:"optionId" binding:"required"`
}

func (h *PollHandler) Vote(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req voteReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Vote(actor, id, req.OptionID); err != nil {
		switch {
		case errors.Is(err, repositories.ErrAlreadyVoted):
			c.JSON(http.StatusConflict, response.ErrorResponse{Error: err.Error(), Code: "ALREADY_VOTED"})
		case errors.Is(err, repositories.ErrPollInactive):
			c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "POLL_INACTIVE"})
		default:
			writeRepoError(c, err)
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Vote recorded"})
}

func (h *PollHandler) Results(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	p, total, err := h.repo.Results(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"poll": p, "totalVotes": total})
}
