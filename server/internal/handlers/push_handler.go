package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type PushHandler struct {
	repo         *repositories.PushSubscriptionRepository
	vapidPubKey  string
}

func NewPushHandler(repo *repositories.PushSubscriptionRepository, vapidPubKey string) *PushHandler {
	return &PushHandler{repo: repo, vapidPubKey: vapidPubKey}
}

// VAPIDPublicKey returns the public key the browser needs to subscribe.
// This is a public endpoint (no auth needed for the key itself, but we
// keep it behind auth so only logged-in users can subscribe).
func (h *PushHandler) VAPIDPublicKey(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"publicKey": h.vapidPubKey})
}

type subscribeReq struct {
	Endpoint  string `json:"endpoint" binding:"required"`
	KeyP256dh string `json:"keyP256dh" binding:"required"`
	KeyAuth   string `json:"keyAuth" binding:"required"`
}

// Subscribe registers or updates a push subscription for the current user.
func (h *PushHandler) Subscribe(c *gin.Context) {
	var req subscribeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	sub := &models.PushSubscription{
		MemberID:  actor.MemberID,
		Endpoint:  req.Endpoint,
		KeyP256dh: req.KeyP256dh,
		KeyAuth:   req.KeyAuth,
		UserAgent: c.GetHeader("User-Agent"),
		IsActive:  true,
	}
	if err := h.repo.Upsert(sub); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "SUBSCRIBE_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "subscribed"})
}

type unsubscribeReq struct {
	Endpoint string `json:"endpoint" binding:"required"`
}

// Unsubscribe removes a push subscription.
func (h *PushHandler) Unsubscribe(c *gin.Context) {
	var req unsubscribeReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	if err := h.repo.Delete(req.Endpoint); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "UNSUBSCRIBE_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "unsubscribed"})
}
