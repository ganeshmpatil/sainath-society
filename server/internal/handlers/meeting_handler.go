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

type MeetingHandler struct {
	repo *repositories.MeetingRepository
}

func NewMeetingHandler(repo *repositories.MeetingRepository) *MeetingHandler {
	return &MeetingHandler{repo: repo}
}

type createMeetingReq struct {
	Title          string             `json:"title" binding:"required,max=200"`
	TitleMr        string             `json:"titleMr,omitempty"`
	MeetingType    models.MeetingType `json:"meetingType" binding:"required"`
	ScheduledAt    time.Time          `json:"scheduledAt" binding:"required"`
	Location       string             `json:"location,omitempty"`
	MeetingURL     string             `json:"meetingUrl,omitempty"`
	Agenda         string             `json:"agenda,omitempty"`
	AgendaMr       string             `json:"agendaMr,omitempty"`
	QuorumRequired int                `json:"quorumRequired,omitempty"`
}

func (h *MeetingHandler) Create(c *gin.Context) {
	var req createMeetingReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	m := &models.Meeting{
		Title: req.Title, TitleMr: req.TitleMr,
		MeetingType: req.MeetingType, Status: models.MeetingPlanned,
		ScheduledAt: req.ScheduledAt, Location: req.Location, MeetingURL: req.MeetingURL,
		Agenda: req.Agenda, AgendaMr: req.AgendaMr,
		QuorumRequired: req.QuorumRequired,
	}
	if err := h.repo.Create(actor, m); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, m)
}

func (h *MeetingHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"meetings": rows, "count": len(rows)})
}

func (h *MeetingHandler) GetByID(c *gin.Context) {
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

type markAttendanceReq struct {
	MemberID uuid.UUID               `json:"memberId" binding:"required"`
	Status   models.AttendanceStatus `json:"status" binding:"required"`
}

func (h *MeetingHandler) MarkAttendance(c *gin.Context) {
	meetingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req markAttendanceReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.MarkAttendance(actor, meetingID, req.MemberID, req.Status); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Attendance marked"})
}

type saveMinutesReq struct {
	Minutes   string `json:"minutes" binding:"required"`
	MinutesMr string `json:"minutesMr,omitempty"`
	Lock      bool   `json:"lock,omitempty"`
}

func (h *MeetingHandler) SaveMinutes(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req saveMinutesReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.SaveMinutes(actor, id, req.Minutes, req.MinutesMr, req.Lock); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Minutes saved"})
}

type addActionItemReq struct {
	Title         string     `json:"title" binding:"required"`
	TitleMr       string     `json:"titleMr,omitempty"`
	Description   string     `json:"description,omitempty"`
	OwnerMemberID uuid.UUID  `json:"ownerMemberId" binding:"required"`
	DueDate       *time.Time `json:"dueDate,omitempty"`
}

func (h *MeetingHandler) AddActionItem(c *gin.Context) {
	meetingID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req addActionItemReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	item := &models.MeetingActionItem{
		MeetingID: meetingID,
		Title:     req.Title, TitleMr: req.TitleMr, Description: req.Description,
		OwnerMemberID: req.OwnerMemberID,
		DueDate:       req.DueDate,
		Status:        models.ActionOpen,
	}
	if err := h.repo.AddActionItem(actor, item); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, item)
}

func (h *MeetingHandler) MyActionItems(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListActionItemsForMember(actor, actor.MemberID)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"actionItems": rows, "count": len(rows)})
}
