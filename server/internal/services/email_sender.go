package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

// EmailSender is the contract for sending emails. The worker stays
// provider-agnostic and takes any implementation at startup.
type EmailSender interface {
	Send(ctx context.Context, to, subject, htmlBody string) (providerRef string, err error)
}

// --- Resend implementation (free tier: 3000 emails/month) ---

type resendSender struct {
	apiKey    string
	fromEmail string
	client    *http.Client
}

// NewResendSender creates a sender backed by the Resend API.
func NewResendSender(apiKey, fromEmail string) EmailSender {
	return &resendSender{
		apiKey:    apiKey,
		fromEmail: fromEmail,
		client:    &http.Client{Timeout: 15 * time.Second},
	}
}

type resendRequest struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	HTML    string   `json:"html"`
}

type resendResponse struct {
	ID string `json:"id"`
}

type resendError struct {
	Message string `json:"message"`
}

func (r *resendSender) Send(ctx context.Context, to, subject, htmlBody string) (string, error) {
	payload := resendRequest{
		From:    r.fromEmail,
		To:      []string{to},
		Subject: subject,
		HTML:    htmlBody,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("marshal email payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.resend.com/emails", bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+r.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := r.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("resend API call: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		var apiErr resendError
		_ = json.Unmarshal(respBody, &apiErr)
		return "", fmt.Errorf("resend API error (%d): %s", resp.StatusCode, apiErr.Message)
	}

	var result resendResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return "", fmt.Errorf("parse resend response: %w", err)
	}

	return result.ID, nil
}

// --- Mock implementation for dev/test ---

type mockEmailSender struct{}

func (m *mockEmailSender) Send(_ context.Context, to, subject, htmlBody string) (string, error) {
	log.Printf("[Email MOCK] To: %s | Subject: %s | Body length: %d", to, subject, len(htmlBody))
	return "mock-email-" + time.Now().Format("20060102150405"), nil
}

// NewMockEmailSender returns a dev-mode email sender that logs instead of sending.
func NewMockEmailSender() EmailSender { return &mockEmailSender{} }
