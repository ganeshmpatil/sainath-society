package services

import (
	"context"
	"log"
	"time"

	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

// WhatsAppSender is the minimal contract implemented by a real WhatsApp
// provider client (e.g. Meta Cloud API, Gupshup, Twilio). The worker stays
// provider-agnostic and takes any implementation at startup.
type WhatsAppSender interface {
	Send(ctx context.Context, toMobile, body string) (providerRef string, err error)
}

// mockWhatsAppSender logs the message instead of making HTTP calls. Used in
// dev and test environments so the rest of the pipeline can be exercised.
type mockWhatsAppSender struct{}

func (m *mockWhatsAppSender) Send(_ context.Context, toMobile, body string) (string, error) {
	log.Printf("[WhatsApp MOCK] → %s : %s", toMobile, body)
	return "mock-" + time.Now().Format("20060102150405"), nil
}

// NewMockWhatsAppSender returns the dev-mode sender.
func NewMockWhatsAppSender() WhatsAppSender { return &mockWhatsAppSender{} }

// NotificationWorker polls the notifications table and dispatches pending
// messages through the configured channel providers.
type NotificationWorker struct {
	repo     *repositories.NotificationRepository
	whatsapp WhatsAppSender
	email    EmailSender
	interval time.Duration
	batch    int
}

func NewNotificationWorker(repo *repositories.NotificationRepository, wa WhatsAppSender, em EmailSender) *NotificationWorker {
	return &NotificationWorker{
		repo:     repo,
		whatsapp: wa,
		email:    em,
		interval: 10 * time.Second,
		batch:    25,
	}
}

// Run starts the dispatch loop until ctx is cancelled.
// Call this from main.go in a goroutine after repositories are wired.
func (w *NotificationWorker) Run(ctx context.Context) {
	log.Println("Notification worker started")
	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			log.Println("Notification worker stopped")
			return
		case <-ticker.C:
			w.dispatchBatch(ctx)
		}
	}
}

// dispatchBatch fetches one batch of pending notifications and sends them.
func (w *NotificationWorker) dispatchBatch(ctx context.Context) {
	pending, err := w.repo.PendingForDispatch(w.batch)
	if err != nil {
		log.Printf("notification worker: fetch failed: %v", err)
		return
	}
	for i := range pending {
		n := &pending[i]

		body := n.BodyMr
		if body == "" || n.Language == "en" {
			body = n.Body
		}

		switch n.Channel {
		case models.ChannelWhatsApp:
			w.dispatchWhatsApp(ctx, n, body)
		case models.ChannelEmail:
			w.dispatchEmail(ctx, n, body)
		default:
			// SMS, Push, In-App — not yet implemented
			continue
		}
	}
}

func (w *NotificationWorker) dispatchWhatsApp(ctx context.Context, n *models.Notification, body string) {
	var mobile string
	if n.Recipient != nil {
		mobile = n.Recipient.Mobile
	}
	if mobile == "" {
		_ = w.repo.MarkFailed(n.ID, "missing recipient mobile")
		return
	}
	ref, err := w.whatsapp.Send(ctx, mobile, body)
	if err != nil {
		_ = w.repo.MarkFailed(n.ID, err.Error())
		return
	}
	_ = w.repo.MarkSent(n.ID, ref)
}

func (w *NotificationWorker) dispatchEmail(ctx context.Context, n *models.Notification, body string) {
	var email string
	if n.Recipient != nil {
		email = n.Recipient.Email
	}
	if email == "" {
		_ = w.repo.MarkFailed(n.ID, "missing recipient email")
		return
	}
	subject := n.Subject
	if subject == "" {
		subject = "Sainath Society Notification"
	}
	htmlBody := WrapInEmailTemplate(subject, body)
	ref, err := w.email.Send(ctx, email, subject, htmlBody)
	if err != nil {
		_ = w.repo.MarkFailed(n.ID, err.Error())
		return
	}
	_ = w.repo.MarkSent(n.ID, ref)
}
