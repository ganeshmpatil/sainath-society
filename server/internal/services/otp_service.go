package services

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log"
	"math/big"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

var (
	ErrOTPNotFound     = errors.New("OTP not found")
	ErrOTPExpired      = errors.New("OTP has expired")
	ErrOTPAlreadyUsed  = errors.New("OTP has already been used")
	ErrOTPMaxAttempts  = errors.New("maximum OTP verification attempts exceeded")
	ErrInvalidOTP      = errors.New("invalid OTP code")
)

// OTPService handles OTP generation and verification
type OTPService struct {
	db         *gorm.DB
	expiry     time.Duration
	maxAttempts int
}

// NewOTPService creates a new OTP service
func NewOTPService(db *gorm.DB) *OTPService {
	return &OTPService{
		db:         db,
		expiry:     5 * time.Minute, // OTP valid for 5 minutes
		maxAttempts: 3,
	}
}

// GenerateOTP creates and stores a new OTP for the given mobile
func (s *OTPService) GenerateOTP(ctx context.Context, mobile, purpose string) (*models.OTP, error) {
	// Invalidate any existing OTPs for this mobile and purpose
	s.db.WithContext(ctx).
		Model(&models.OTP{}).
		Where("mobile = ? AND purpose = ? AND is_used = ?", mobile, purpose, false).
		Update("is_used", true)

	// Generate 6-digit OTP
	code, err := generateRandomCode(6)
	if err != nil {
		return nil, fmt.Errorf("failed to generate OTP: %w", err)
	}

	otp := &models.OTP{
		ID:          uuid.New(),
		Mobile:      mobile,
		Code:        code,
		Purpose:     purpose,
		ExpiresAt:   time.Now().Add(s.expiry),
		MaxAttempts: s.maxAttempts,
	}

	if err := s.db.WithContext(ctx).Create(otp).Error; err != nil {
		return nil, fmt.Errorf("failed to save OTP: %w", err)
	}

	// Send OTP via SMS (mock implementation)
	if err := s.sendSMS(mobile, code); err != nil {
		log.Printf("Failed to send SMS to %s: %v", mobile, err)
		// Don't fail the request, OTP is still valid
	}

	return otp, nil
}

// VerifyOTP verifies the OTP code for the given mobile
func (s *OTPService) VerifyOTP(ctx context.Context, mobile, code, purpose string) error {
	var otp models.OTP

	err := s.db.WithContext(ctx).
		Where("mobile = ? AND purpose = ? AND is_used = ?", mobile, purpose, false).
		Order("created_at DESC").
		First(&otp).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return ErrOTPNotFound
		}
		return err
	}

	// Check if expired
	if otp.IsExpired() {
		return ErrOTPExpired
	}

	// Check max attempts
	if otp.Attempts >= otp.MaxAttempts {
		return ErrOTPMaxAttempts
	}

	// Increment attempts
	otp.Attempts++
	s.db.WithContext(ctx).Save(&otp)

	// Verify code
	if otp.Code != code {
		return ErrInvalidOTP
	}

	// Mark as used
	now := time.Now()
	otp.IsUsed = true
	otp.UsedAt = &now
	s.db.WithContext(ctx).Save(&otp)

	return nil
}

// sendSMS sends OTP via SMS (mock implementation)
func (s *OTPService) sendSMS(mobile, code string) error {
	// In production, integrate with SMS gateway (Twilio, AWS SNS, etc.)
	// For now, just log the OTP
	log.Printf("===========================================")
	log.Printf("SMS OTP for %s: %s", mobile, code)
	log.Printf("===========================================")
	return nil
}

// generateRandomCode generates a random numeric code of given length
func generateRandomCode(length int) (string, error) {
	const digits = "0123456789"
	code := make([]byte, length)

	for i := range code {
		num, err := rand.Int(rand.Reader, big.NewInt(int64(len(digits))))
		if err != nil {
			return "", err
		}
		code[i] = digits[num.Int64()]
	}

	return string(code), nil
}
