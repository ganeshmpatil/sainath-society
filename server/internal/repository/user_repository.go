package repository

import (
	"context"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

const (
	preloadMember     = "Member"
	preloadMemberFlat = "Member.Flat"
	preloadFlatWing   = "Member.Flat.Wing"
	whereID           = "id = ?"
)

// UserRepository handles user database operations
type UserRepository struct {
	db *gorm.DB
}

// NewUserRepository creates a new user repository
func NewUserRepository(db *gorm.DB) *UserRepository {
	return &UserRepository{db: db}
}

// FindByEmail finds a user by email
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*models.User, error) {
	var user models.User
	err := r.db.WithContext(ctx).
		Preload(preloadMember).
		Preload(preloadMemberFlat).
		Preload(preloadFlatWing).
		Where("email = ?", email).
		First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByID finds a user by ID
func (r *UserRepository) FindByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	var user models.User
	err := r.db.WithContext(ctx).
		Preload(preloadMember).
		Preload(preloadMemberFlat).
		Preload(preloadFlatWing).
		Where(whereID, id).
		First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByMobile finds a user by mobile
func (r *UserRepository) FindByMobile(ctx context.Context, mobile string) (*models.User, error) {
	var user models.User
	err := r.db.WithContext(ctx).
		Preload(preloadMember).
		Preload(preloadMemberFlat).
		Preload(preloadFlatWing).
		Where("mobile = ?", mobile).
		First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// Update updates a user
func (r *UserRepository) Update(ctx context.Context, user *models.User) error {
	return r.db.WithContext(ctx).Save(user).Error
}

// UpdateRefreshToken updates user's refresh token
func (r *UserRepository) UpdateRefreshToken(ctx context.Context, userID uuid.UUID, tokenHash string, expiresAt interface{}) error {
	return r.db.WithContext(ctx).
		Model(&models.User{}).
		Where(whereID, userID).
		Updates(map[string]interface{}{
			"refresh_token_hash":       tokenHash,
			"refresh_token_expires_at": expiresAt,
		}).Error
}

// UpdateLastLogin updates user's last login info
func (r *UserRepository) UpdateLastLogin(ctx context.Context, userID uuid.UUID, ip string) error {
	return r.db.WithContext(ctx).
		Model(&models.User{}).
		Where(whereID, userID).
		Updates(map[string]interface{}{
			"last_login_at":         gorm.Expr("NOW()"),
			"last_login_ip":         ip,
			"failed_login_attempts": 0,
			"locked_until":          nil,
		}).Error
}

// FindAll returns all users
func (r *UserRepository) FindAll(ctx context.Context) ([]models.User, error) {
	var users []models.User
	err := r.db.WithContext(ctx).
		Preload(preloadMember).
		Preload(preloadMemberFlat).
		Preload(preloadFlatWing).
		Order("created_at DESC").
		Find(&users).Error
	return users, err
}

// Create creates a new user
func (r *UserRepository) Create(ctx context.Context, user *models.User) error {
	return r.db.WithContext(ctx).Create(user).Error
}
