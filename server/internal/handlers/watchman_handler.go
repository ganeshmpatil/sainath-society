package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type WatchmanHandler struct {
	repo *repositories.WatchmanRepository
}

func NewWatchmanHandler(repo *repositories.WatchmanRepository) *WatchmanHandler {
	return &WatchmanHandler{repo: repo}
}

type createWatchmanReq struct {
	Name          string `json:"name" binding:"required,max=100"`
	NameMr        string `json:"nameMr,omitempty"`
	Mobile        string `json:"mobile" binding:"required,max=15"`
	DutyStartTime string `json:"dutyStartTime" binding:"required,max=5"`
	DutyEndTime   string `json:"dutyEndTime" binding:"required,max=5"`
}

func (h *WatchmanHandler) Create(c *gin.Context) {
	var req createWatchmanReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	w := &models.Watchman{
		Name:          req.Name,
		NameMr:        req.NameMr,
		Mobile:        req.Mobile,
		DutyStartTime: req.DutyStartTime,
		DutyEndTime:   req.DutyEndTime,
		IsActive:      true,
	}
	if err := h.repo.Create(actor, w); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, w)
}

func (h *WatchmanHandler) List(c *gin.Context) {
	rows, err := h.repo.List()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"watchmen": rows, "count": len(rows)})
}

func (h *WatchmanHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	w, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, w)
}

func (h *WatchmanHandler) Update(c *gin.Context) {
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

func (h *WatchmanHandler) Delete(c *gin.Context) {
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
