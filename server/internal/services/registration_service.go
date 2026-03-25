package services

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

var (
	ErrMemberNotFound      = errors.New("mobile number not registered in society")
	ErrMemberAlreadyRegistered = errors.New("member has already registered")
	ErrMemberInactive      = errors.New("member account is inactive")
	ErrEmailAlreadyExists  = errors.New("email already in use")
)

// RegistrationService handles member registration
type RegistrationService struct {
	db         *gorm.DB
	otpService *OTPService
}

// NewRegistrationService creates a new registration service
func NewRegistrationService(db *gorm.DB, otpService *OTPService) *RegistrationService {
	return &RegistrationService{
		db:         db,
		otpService: otpService,
	}
}

// InitiateRegistration starts the registration process by validating mobile and sending OTP
func (s *RegistrationService) InitiateRegistration(ctx context.Context, mobile string) (*models.Member, error) {
	// Find member by mobile
	var member models.Member
	err := s.db.WithContext(ctx).
		Preload("Flat").
		Preload("Flat.Wing").
		Where("mobile = ?", mobile).
		First(&member).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrMemberNotFound
		}
		return nil, err
	}

	// Check if already registered
	if member.IsRegistered {
		return nil, ErrMemberAlreadyRegistered
	}

	// Check if active
	if !member.IsActive {
		return nil, ErrMemberInactive
	}

	// Generate and send OTP
	_, err = s.otpService.GenerateOTP(ctx, mobile, "registration")
	if err != nil {
		return nil, err
	}

	return &member, nil
}

// VerifyOTP verifies the OTP for registration
func (s *RegistrationService) VerifyOTP(ctx context.Context, mobile, code string) error {
	return s.otpService.VerifyOTP(ctx, mobile, code, "registration")
}

// CompleteRegistration creates user credentials after OTP verification
func (s *RegistrationService) CompleteRegistration(ctx context.Context, mobile, email, password string) (*models.User, *models.Member, error) {
	// Find member
	var member models.Member
	err := s.db.WithContext(ctx).
		Preload("Flat").
		Preload("Flat.Wing").
		Where("mobile = ?", mobile).
		First(&member).Error

	if err != nil {
		return nil, nil, ErrMemberNotFound
	}

	// Check if already registered
	if member.IsRegistered {
		return nil, nil, ErrMemberAlreadyRegistered
	}

	// Check if email already exists
	var existingUser models.User
	err = s.db.WithContext(ctx).Where("email = ?", email).First(&existingUser).Error
	if err == nil {
		return nil, nil, ErrEmailAlreadyExists
	}

	// Hash password
	passwordHash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, nil, err
	}

	// Create user in transaction
	var user *models.User
	err = s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// Create user
		user = &models.User{
			ID:           uuid.New(),
			Email:        email,
			Mobile:       mobile,
			PasswordHash: string(passwordHash),
			MemberID:     member.ID,
			IsActive:     true,
		}

		if err := tx.Create(user).Error; err != nil {
			return err
		}

		// Update member as registered
		now := time.Now()
		member.IsRegistered = true
		member.RegisteredAt = &now
		member.UserID = &user.ID

		if err := tx.Save(&member).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		return nil, nil, err
	}

	return user, &member, nil
}

// GetMemberByMobile finds a member by mobile number
func (s *RegistrationService) GetMemberByMobile(ctx context.Context, mobile string) (*models.Member, error) {
	var member models.Member
	err := s.db.WithContext(ctx).
		Preload("Flat").
		Preload("Flat.Wing").
		Where("mobile = ?", mobile).
		First(&member).Error

	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrMemberNotFound
		}
		return nil, err
	}

	return &member, nil
}

// ResendOTP generates a new OTP for registration
func (s *RegistrationService) ResendOTP(ctx context.Context, mobile string) error {
	// Verify member exists and not registered
	member, err := s.GetMemberByMobile(ctx, mobile)
	if err != nil {
		return err
	}

	if member.IsRegistered {
		return ErrMemberAlreadyRegistered
	}

	if !member.IsActive {
		return ErrMemberInactive
	}

	_, err = s.otpService.GenerateOTP(ctx, mobile, "registration")
	return err
}
