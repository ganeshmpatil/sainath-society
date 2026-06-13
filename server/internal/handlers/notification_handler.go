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

type NotificationHandler struct {
	repo       *repositories.NotificationRepository
	memberRepo *repositories.MemberRepository
}

func NewNotificationHandler(repo *repositories.NotificationRepository, memberRepo *repositories.MemberRepository) *NotificationHandler {
	return &NotificationHandler{repo: repo, memberRepo: memberRepo}
}

type sendEmailReq struct {
	RecipientIDs []string `json:"recipientIds" binding:"required,min=1"`
	Subject      string   `json:"subject" binding:"required,max=200"`
	Body         string   `json:"body" binding:"required"`
	BodyMr       string   `json:"bodyMr,omitempty"`
	EventType    string   `json:"eventType,omitempty"`
}

type sendEmailToAllReq struct {
	Subject   string `json:"subject" binding:"required,max=200"`
	Body      string `json:"body" binding:"required"`
	BodyMr    string `json:"bodyMr,omitempty"`
	EventType string `json:"eventType,omitempty"`
}

// SendEmail queues email notifications to specific recipients (admin only).
func (h *NotificationHandler) SendEmail(c *gin.Context) {
	actor := middleware.GetActor(c)
	if !actor.IsAdmin() {
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: "only admins can send email notifications", Code: "FORBIDDEN"})
		return
	}

	var req sendEmailReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}

	var queued int
	var skipped int
	for _, idStr := range req.RecipientIDs {
		recipientID, err := uuid.Parse(idStr)
		if err != nil {
			skipped++
			continue
		}
		n := &models.Notification{
			RecipientID: recipientID,
			Channel:     models.ChannelEmail,
			Subject:     req.Subject,
			Body:        req.Body,
			BodyMr:      req.BodyMr,
			EventType:   req.EventType,
			Language:     "en",
		}
		if err := h.repo.Enqueue(n); err != nil {
			skipped++
			continue
		}
		queued++
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "email notifications queued",
		"queued":  queued,
		"skipped": skipped,
	})
}

// SendEmailToAll queues email notifications to all active members with email addresses (admin only).
func (h *NotificationHandler) SendEmailToAll(c *gin.Context) {
	actor := middleware.GetActor(c)
	if !actor.IsAdmin() {
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: "only admins can send email notifications", Code: "FORBIDDEN"})
		return
	}

	var req sendEmailToAllReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}

	members, err := h.memberRepo.ListActiveWithEmail()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to fetch members", Code: "INTERNAL_ERROR"})
		return
	}

	var queued int
	for _, m := range members {
		n := &models.Notification{
			RecipientID: m.ID,
			Channel:     models.ChannelEmail,
			Subject:     req.Subject,
			Body:        req.Body,
			BodyMr:      req.BodyMr,
			EventType:   req.EventType,
			Language:     "en",
		}
		if err := h.repo.Enqueue(n); err != nil {
			continue
		}
		queued++
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      "email notifications queued to all members",
		"queued":       queued,
		"totalMembers": len(members),
	})
}

// ListInbox returns notifications for the authenticated user.
func (h *NotificationHandler) ListInbox(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListForRecipient(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to fetch notifications", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, rows)
}

// MarkRead marks a notification as read.
func (h *NotificationHandler) MarkRead(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "invalid id", Code: "INVALID_ID"})
		return
	}
	if err := h.repo.MarkRead(id); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to mark read", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "marked as read"})
}

// UnreadCount returns the count of unread notifications.
func (h *NotificationHandler) UnreadCount(c *gin.Context) {
	actor := middleware.GetActor(c)
	count, err := h.repo.UnreadCount(actor.MemberID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "failed to count", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"count": count})
}
