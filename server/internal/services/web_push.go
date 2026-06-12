package services

import (
	"encoding/json"
	"log"
	"net/http"

	webpush "github.com/SherClockHolmes/webpush-go"
	"github.com/google/uuid"

	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

// PushPayload is the JSON sent to the service worker.
type PushPayload struct {
	Title      string `json:"title"`
	Body       string `json:"body"`
	Icon       string `json:"icon,omitempty"`
	Badge      string `json:"badge,omitempty"`
	URL        string `json:"url,omitempty"`
	EventType  string `json:"eventType,omitempty"`
	ResourceID string `json:"resourceId,omitempty"`
}

// WebPushService sends push notifications to browsers.
type WebPushService struct {
	subRepo    *repositories.PushSubscriptionRepository
	vapidPub   string
	vapidPriv  string
	vapidEmail string // contact email for VAPID (mailto:)
}

func NewWebPushService(
	subRepo *repositories.PushSubscriptionRepository,
	vapidPublic, vapidPrivate, contactEmail string,
) *WebPushService {
	return &WebPushService{
		subRepo:    subRepo,
		vapidPub:   vapidPublic,
		vapidPriv:  vapidPrivate,
		vapidEmail: contactEmail,
	}
}

// SendToMember sends a push notification to all devices of a single member.
func (s *WebPushService) SendToMember(memberID uuid.UUID, payload PushPayload) {
	subs, err := s.subRepo.ListForMember(memberID)
	if err != nil {
		log.Printf("webpush: failed to list subs for member %s: %v", memberID, err)
		return
	}
	s.sendToSubscriptions(subs, payload)
}

// SendToMembers sends a push notification to multiple members.
func (s *WebPushService) SendToMembers(memberIDs []uuid.UUID, payload PushPayload) {
	subs, err := s.subRepo.ListForMembers(memberIDs)
	if err != nil {
		log.Printf("webpush: failed to list subs for members: %v", err)
		return
	}
	s.sendToSubscriptions(subs, payload)
}

// Broadcast sends a push notification to all subscribed browsers.
func (s *WebPushService) Broadcast(payload PushPayload) {
	subs, err := s.subRepo.ListAll()
	if err != nil {
		log.Printf("webpush: failed to list all subs: %v", err)
		return
	}
	s.sendToSubscriptions(subs, payload)
}

func (s *WebPushService) sendToSubscriptions(subs []models.PushSubscription, payload PushPayload) {
	data, err := json.Marshal(payload)
	if err != nil {
		log.Printf("webpush: marshal failed: %v", err)
		return
	}

	for _, sub := range subs {
		go s.sendOne(sub, data)
	}
}

func (s *WebPushService) sendOne(sub models.PushSubscription, data []byte) {
	wSub := &webpush.Subscription{
		Endpoint: sub.Endpoint,
		Keys: webpush.Keys{
			P256dh: sub.KeyP256dh,
			Auth:   sub.KeyAuth,
		},
	}

	resp, err := webpush.SendNotification(data, wSub, &webpush.Options{
		Subscriber:      s.vapidEmail,
		VAPIDPublicKey:  s.vapidPub,
		VAPIDPrivateKey: s.vapidPriv,
		TTL:             86400, // 24 hours
	})
	if err != nil {
		log.Printf("webpush: send failed to %s: %v", sub.Endpoint[:40], err)
		return
	}
	defer resp.Body.Close()

	// 410 Gone → browser unsubscribed, deactivate
	if resp.StatusCode == http.StatusGone {
		log.Printf("webpush: subscription gone, deactivating: %s", sub.Endpoint[:40])
		_ = s.subRepo.DeactivateByEndpoint(sub.Endpoint)
		return
	}

	if resp.StatusCode >= 400 {
		log.Printf("webpush: HTTP %d for %s", resp.StatusCode, sub.Endpoint[:40])
	}
}
