package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/request"
	"sainath-society/internal/dto/response"
	"sainath-society/internal/services"
)

// AuthHandler handles authentication endpoints
type AuthHandler struct {
	authService *services.AuthService
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

// Login handles user login
// @Summary Login
// @Description Authenticate user and return tokens
// @Tags Auth
// @Accept json
// @Produce json
// @Param request body request.LoginRequest true "Login credentials"
// @Success 200 {object} response.LoginResponse
// @Failure 400 {object} response.ErrorResponse
// @Failure 401 {object} response.ErrorResponse
// @Failure 423 {object} response.ErrorResponse
// @Router /api/v1/auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var req request.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{
			Error: "Invalid request body",
			Code:  "VALIDATION_ERROR",
		})
		return
	}

	clientIP := c.ClientIP()
	loginResp, refreshToken, err := h.authService.Login(c.Request.Context(), req.Email, req.Password, clientIP)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrInvalidCredentials):
			c.JSON(http.StatusUnauthorized, response.ErrorResponse{
				Error: "Invalid email or password",
				Code:  "INVALID_CREDENTIALS",
			})
		case errors.Is(err, services.ErrAccountLocked):
			c.JSON(http.StatusLocked, response.ErrorResponse{
				Error: "Account locked due to too many failed attempts. Try again in 30 minutes.",
				Code:  "ACCOUNT_LOCKED",
			})
		case errors.Is(err, services.ErrAccountInactive):
			c.JSON(http.StatusForbidden, response.ErrorResponse{
				Error: "Account is inactive. Please contact administrator.",
				Code:  "ACCOUNT_INACTIVE",
			})
		default:
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{
				Error: "An error occurred during login",
				Code:  "INTERNAL_ERROR",
			})
		}
		return
	}

	// Set refresh token in httpOnly cookie
	c.SetCookie(
		"refreshToken",
		refreshToken,
		int(7*24*time.Hour.Seconds()), // 7 days
		"/api/v1/auth",
		"",    // domain
		false, // secure (set true in production)
		true,  // httpOnly
	)

	c.JSON(http.StatusOK, loginResp)
}

// RefreshToken handles token refresh
// @Summary Refresh Token
// @Description Refresh access token using refresh token
// @Tags Auth
// @Accept json
// @Produce json
// @Success 200 {object} response.RefreshResponse
// @Failure 401 {object} response.ErrorResponse
// @Router /api/v1/auth/refresh [post]
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	// Get refresh token from cookie
	refreshToken, err := c.Cookie("refreshToken")
	if err != nil {
		// Try from request body as fallback
		var req request.RefreshRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusUnauthorized, response.ErrorResponse{
				Error: "Refresh token required",
				Code:  "TOKEN_REQUIRED",
			})
			return
		}
		refreshToken = req.RefreshToken
	}

	refreshResp, newRefreshToken, err := h.authService.RefreshToken(c.Request.Context(), refreshToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, response.ErrorResponse{
			Error: "Invalid or expired refresh token",
			Code:  "INVALID_REFRESH_TOKEN",
		})
		return
	}

	// Update refresh token cookie
	c.SetCookie(
		"refreshToken",
		newRefreshToken,
		int(7*24*time.Hour.Seconds()),
		"/api/v1/auth",
		"",
		false,
		true,
	)

	c.JSON(http.StatusOK, refreshResp)
}

// GetMe returns current user info
// @Summary Get Current User
// @Description Get current authenticated user details
// @Tags Auth
// @Produce json
// @Security BearerAuth
// @Success 200 {object} response.UserResponse
// @Failure 401 {object} response.ErrorResponse
// @Router /api/v1/auth/me [get]
func (h *AuthHandler) GetMe(c *gin.Context) {
	userIDStr, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, response.ErrorResponse{
			Error: "User not authenticated",
			Code:  "UNAUTHORIZED",
		})
		return
	}

	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusUnauthorized, response.ErrorResponse{
			Error: "Invalid user ID",
			Code:  "INVALID_USER",
		})
		return
	}

	user, err := h.authService.GetCurrentUser(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, response.ErrorResponse{
			Error: "User not found",
			Code:  "USER_NOT_FOUND",
		})
		return
	}

	c.JSON(http.StatusOK, user)
}

// ChangePasswordRequest is the body for PUT /auth/password.
type changePasswordReq struct {
	CurrentPassword string `json:"currentPassword" binding:"required"`
	NewPassword     string `json:"newPassword" binding:"required,min=8"`
}

// ChangePassword updates the current user's password.
func (h *AuthHandler) ChangePassword(c *gin.Context) {
	userIDStr, _ := c.Get("userID")
	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusUnauthorized, response.ErrorResponse{Error: "Invalid user", Code: "INVALID_USER"})
		return
	}
	var req changePasswordReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	if err := h.authService.ChangePassword(c.Request.Context(), userID, req.CurrentPassword, req.NewPassword); err != nil {
		switch {
		case errors.Is(err, services.ErrPasswordMismatch):
			c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Current password is incorrect", Code: "WRONG_PASSWORD"})
		default:
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "UPDATE_FAILED"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Password updated successfully"})
}

// Logout handles user logout
// @Summary Logout
// @Description Invalidate refresh token
// @Tags Auth
// @Security BearerAuth
// @Success 200 {object} response.MessageResponse
// @Failure 401 {object} response.ErrorResponse
// @Router /api/v1/auth/logout [post]
func (h *AuthHandler) Logout(c *gin.Context) {
	userIDStr, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, response.ErrorResponse{
			Error: "User not authenticated",
			Code:  "UNAUTHORIZED",
		})
		return
	}

	userID, err := uuid.Parse(userIDStr.(string))
	if err != nil {
		c.JSON(http.StatusUnauthorized, response.ErrorResponse{
			Error: "Invalid user ID",
			Code:  "INVALID_USER",
		})
		return
	}

	if err := h.authService.Logout(c.Request.Context(), userID); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{
			Error: "Failed to logout",
			Code:  "LOGOUT_FAILED",
		})
		return
	}

	// Clear refresh token cookie
	c.SetCookie(
		"refreshToken",
		"",
		-1,
		"/api/v1/auth",
		"",
		false,
		true,
	)

	c.JSON(http.StatusOK, response.MessageResponse{
		Message: "Logged out successfully",
	})
}
