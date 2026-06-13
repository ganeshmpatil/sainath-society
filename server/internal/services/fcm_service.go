package services

import (
	"bytes"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	jwtgo "github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"sainath-society/internal/repositories"
)

// FCMService sends push notifications to Android/iOS devices via FCM HTTP v1 API.
type FCMService struct {
	subRepo    *repositories.PushSubscriptionRepository
	projectID  string
	privateKey *rsa.PrivateKey
	clientEmail string

	// Cached OAuth2 access token
	mu          sync.Mutex
	accessToken string
	tokenExpiry time.Time
}

// FCMServiceAccount holds the fields we need from the Firebase service account JSON.
type FCMServiceAccount struct {
	ProjectID   string `json:"project_id"`
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
}

// NewFCMService creates a new FCM service from the service account JSON bytes.
func NewFCMService(subRepo *repositories.PushSubscriptionRepository, saJSON []byte) (*FCMService, error) {
	var sa FCMServiceAccount
	if err := json.Unmarshal(saJSON, &sa); err != nil {
		return nil, fmt.Errorf("fcm: failed to parse service account JSON: %w", err)
	}

	block, _ := pem.Decode([]byte(sa.PrivateKey))
	if block == nil {
		return nil, fmt.Errorf("fcm: failed to decode PEM private key")
	}

	key, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("fcm: failed to parse private key: %w", err)
	}

	rsaKey, ok := key.(*rsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("fcm: private key is not RSA")
	}

	return &FCMService{
		subRepo:     subRepo,
		projectID:   sa.ProjectID,
		privateKey:  rsaKey,
		clientEmail: sa.ClientEmail,
	}, nil
}

// getAccessToken returns a valid OAuth2 access token, refreshing if expired.
func (s *FCMService) getAccessToken() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.accessToken != "" && time.Now().Before(s.tokenExpiry) {
		return s.accessToken, nil
	}

	now := time.Now()
	claims := jwtgo.MapClaims{
		"iss":   s.clientEmail,
		"sub":   s.clientEmail,
		"aud":   "https://oauth2.googleapis.com/token",
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
		"scope": "https://www.googleapis.com/auth/firebase.messaging",
	}

	token := jwtgo.NewWithClaims(jwtgo.SigningMethodRS256, claims)
	signedJWT, err := token.SignedString(s.privateKey)
	if err != nil {
		return "", fmt.Errorf("fcm: failed to sign JWT: %w", err)
	}

	// Exchange JWT for access token
	resp, err := http.PostForm("https://oauth2.googleapis.com/token", map[string][]string{
		"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"},
		"assertion":  {signedJWT},
	})
	if err != nil {
		return "", fmt.Errorf("fcm: token exchange failed: %w", err)
	}
	defer resp.Body.Close()

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("fcm: failed to decode token response: %w", err)
	}

	s.accessToken = tokenResp.AccessToken
	s.tokenExpiry = now.Add(time.Duration(tokenResp.ExpiresIn-60) * time.Second) // refresh 60s early
	return s.accessToken, nil
}

// FCMMessage is the payload sent to a single device.
type FCMMessage struct {
	Title      string            `json:"title"`
	Body       string            `json:"body"`
	Data       map[string]string `json:"data,omitempty"`
}

// SendToMember sends a push notification to all FCM devices of a member.
func (s *FCMService) SendToMember(memberID uuid.UUID, msg FCMMessage) {
	subs, err := s.subRepo.ListForMemberByPlatform(memberID, "fcm")
	if err != nil {
		log.Printf("fcm: failed to list tokens for member %s: %v", memberID, err)
		return
	}
	for _, sub := range subs {
		go s.sendOne(sub.Endpoint, msg)
	}
}

// SendToMembers sends to multiple members' FCM devices.
func (s *FCMService) SendToMembers(memberIDs []uuid.UUID, msg FCMMessage) {
	subs, err := s.subRepo.ListForMembersByPlatform(memberIDs, "fcm")
	if err != nil {
		log.Printf("fcm: failed to list tokens: %v", err)
		return
	}
	for _, sub := range subs {
		go s.sendOne(sub.Endpoint, msg)
	}
}

// Broadcast sends to all registered FCM devices.
func (s *FCMService) Broadcast(msg FCMMessage) {
	subs, err := s.subRepo.ListAllByPlatform("fcm")
	if err != nil {
		log.Printf("fcm: failed to list all tokens: %v", err)
		return
	}
	for _, sub := range subs {
		go s.sendOne(sub.Endpoint, msg)
	}
}

func (s *FCMService) sendOne(token string, msg FCMMessage) {
	accessToken, err := s.getAccessToken()
	if err != nil {
		log.Printf("fcm: auth failed: %v", err)
		return
	}

	payload := map[string]interface{}{
		"message": map[string]interface{}{
			"token": token,
			"notification": map[string]string{
				"title": msg.Title,
				"body":  msg.Body,
			},
			"android": map[string]interface{}{
				"priority": "high",
				"notification": map[string]string{
					"channel_id": "society_notifications",
				},
			},
		},
	}
	if len(msg.Data) > 0 {
		payload["message"].(map[string]interface{})["data"] = msg.Data
	}

	body, _ := json.Marshal(payload)
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", s.projectID)

	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		log.Printf("fcm: request creation failed: %v", err)
		return
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("fcm: send failed: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusGone {
		// Token is invalid/expired, deactivate
		log.Printf("fcm: token expired/invalid (HTTP %d), deactivating", resp.StatusCode)
		_ = s.subRepo.DeactivateByEndpoint(token)
		return
	}

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		log.Printf("fcm: HTTP %d: %s", resp.StatusCode, string(respBody))
	}
}
