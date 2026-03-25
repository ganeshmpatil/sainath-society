package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/models"
	"sainath-society/internal/repository"
	"sainath-society/pkg/jwt"
)

var (
	ErrInvalidCredentials  = errors.New("invalid email or password")
	ErrAccountLocked       = errors.New("account is locked due to too many failed attempts")
	ErrAccountInactive     = errors.New("account is inactive")
	ErrInvalidRefreshToken = errors.New("invalid or expired refresh token")
)

// AuthService handles authentication logic
type AuthService struct {
	userRepo   *repository.UserRepository
	jwtManager *jwt.Manager
}

// NewAuthService creates a new auth service
func NewAuthService(userRepo *repository.UserRepository, jwtManager *jwt.Manager) *AuthService {
	return &AuthService{
		userRepo:   userRepo,
		jwtManager: jwtManager,
	}
}

// Login authenticates a user and returns tokens
func (s *AuthService) Login(ctx context.Context, email, password, clientIP string) (*response.LoginResponse, string, error) {
	// Find user with member info
	user, err := s.userRepo.FindByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, "", ErrInvalidCredentials
		}
		return nil, "", err
	}

	// Check if account is active
	if !user.IsActive {
		return nil, "", ErrAccountInactive
	}

	// Check if account is locked
	if user.IsLocked() {
		return nil, "", ErrAccountLocked
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		user.IncrementFailedAttempts()
		_ = s.userRepo.Update(ctx, user)
		return nil, "", ErrInvalidCredentials
	}

	// Get member info
	member := user.Member
	if member == nil {
		return nil, "", errors.New("member info not found")
	}

	// Get flat info
	flatID := ""
	flatNumber := ""
	if member.Flat != nil {
		flatID = member.FlatID.String()
		flatNumber = member.Flat.FlatNumber
	}

	// Get permissions
	permissions := models.GetPermissionsForRole(member.Role)

	// Generate tokens
	tokenPair, err := s.jwtManager.GenerateTokenPair(
		user.ID,
		user.Email,
		string(member.Role),
		flatID,
		flatNumber,
		permissions,
	)
	if err != nil {
		return nil, "", err
	}

	// Hash and store refresh token
	refreshTokenHash := hashToken(tokenPair.RefreshToken)
	expiresAt := time.Now().Add(7 * 24 * time.Hour)
	if err := s.userRepo.UpdateRefreshToken(ctx, user.ID, refreshTokenHash, expiresAt); err != nil {
		return nil, "", err
	}

	// Update last login
	if err := s.userRepo.UpdateLastLogin(ctx, user.ID, clientIP); err != nil {
		// Non-critical, log but don't fail
	}

	return &response.LoginResponse{
		AccessToken: tokenPair.AccessToken,
		ExpiresIn:   tokenPair.ExpiresIn,
		ExpiresAt:   tokenPair.ExpiresAt,
		User: response.UserResponse{
			ID:          user.ID.String(),
			Name:        member.Name,
			Email:       user.Email,
			Phone:       user.Mobile,
			Role:        string(member.Role),
			Designation: member.Designation,
			FlatID:      flatID,
			FlatNumber:  flatNumber,
			Permissions: permissions,
			IsActive:    user.IsActive,
		},
	}, tokenPair.RefreshToken, nil
}

// RefreshToken validates refresh token and issues new access token
func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*response.RefreshResponse, string, error) {
	// Validate refresh token
	userID, err := s.jwtManager.ValidateRefreshToken(refreshToken)
	if err != nil {
		return nil, "", ErrInvalidRefreshToken
	}

	// Find user
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, "", ErrInvalidRefreshToken
	}

	// Verify refresh token hash matches
	if user.RefreshTokenHash != hashToken(refreshToken) {
		return nil, "", ErrInvalidRefreshToken
	}

	// Check if account is active
	if !user.IsActive {
		return nil, "", ErrAccountInactive
	}

	// Get member info
	member := user.Member
	if member == nil {
		return nil, "", errors.New("member info not found")
	}

	// Get flat info
	flatID := ""
	flatNumber := ""
	if member.Flat != nil {
		flatID = member.FlatID.String()
		flatNumber = member.Flat.FlatNumber
	}

	// Get permissions
	permissions := models.GetPermissionsForRole(member.Role)

	// Generate new token pair (token rotation)
	tokenPair, err := s.jwtManager.GenerateTokenPair(
		user.ID,
		user.Email,
		string(member.Role),
		flatID,
		flatNumber,
		permissions,
	)
	if err != nil {
		return nil, "", err
	}

	// Update refresh token (rotation)
	refreshTokenHash := hashToken(tokenPair.RefreshToken)
	expiresAt := time.Now().Add(7 * 24 * time.Hour)
	if err := s.userRepo.UpdateRefreshToken(ctx, user.ID, refreshTokenHash, expiresAt); err != nil {
		return nil, "", err
	}

	return &response.RefreshResponse{
		AccessToken: tokenPair.AccessToken,
		ExpiresIn:   tokenPair.ExpiresIn,
		ExpiresAt:   tokenPair.ExpiresAt,
	}, tokenPair.RefreshToken, nil
}

// GetCurrentUser returns current user info
func (s *AuthService) GetCurrentUser(ctx context.Context, userID uuid.UUID) (*response.UserResponse, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	member := user.Member
	if member == nil {
		return nil, errors.New("member info not found")
	}

	flatID := ""
	flatNumber := ""
	if member.Flat != nil {
		flatID = member.FlatID.String()
		flatNumber = member.Flat.FlatNumber
	}

	permissions := models.GetPermissionsForRole(member.Role)

	return &response.UserResponse{
		ID:          user.ID.String(),
		Name:        member.Name,
		Email:       user.Email,
		Phone:       user.Mobile,
		Role:        string(member.Role),
		Designation: member.Designation,
		FlatID:      flatID,
		FlatNumber:  flatNumber,
		Permissions: permissions,
		IsActive:    user.IsActive,
	}, nil
}

// Logout invalidates user's refresh token
func (s *AuthService) Logout(ctx context.Context, userID uuid.UUID) error {
	return s.userRepo.UpdateRefreshToken(ctx, userID, "", nil)
}

// hashToken creates SHA256 hash of token
func hashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}
