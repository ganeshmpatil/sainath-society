package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"sainath-society/internal/dto/request"
	"sainath-society/internal/dto/response"
	"sainath-society/internal/services"
)

// RegistrationHandler handles registration endpoints
type RegistrationHandler struct {
	registrationService *services.RegistrationService
}

// NewRegistrationHandler creates a new registration handler
func NewRegistrationHandler(registrationService *services.RegistrationService) *RegistrationHandler {
	return &RegistrationHandler{registrationService: registrationService}
}

// InitiateRegistration starts the registration process
// @Summary Initiate Registration
// @Description Validate mobile and send OTP
// @Tags Registration
// @Accept json
// @Produce json
// @Param request body request.InitiateRegistrationRequest true "Mobile number"
// @Success 200 {object} response.InitiateRegistrationResponse
// @Failure 400 {object} response.ErrorResponse
// @Failure 404 {object} response.ErrorResponse
// @Router /api/v1/registration/initiate [post]
func (h *RegistrationHandler) InitiateRegistration(c *gin.Context) {
	var req request.InitiateRegistrationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{
			Error: "Invalid request body",
			Code:  "VALIDATION_ERROR",
		})
		return
	}

	member, err := h.registrationService.InitiateRegistration(c.Request.Context(), req.Mobile)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrMemberNotFound):
			c.JSON(http.StatusNotFound, response.ErrorResponse{
				Error: "Mobile number not registered in society. Please contact your admin.",
				Code:  "MEMBER_NOT_FOUND",
			})
		case errors.Is(err, services.ErrMemberAlreadyRegistered):
			c.JSON(http.StatusConflict, response.ErrorResponse{
				Error: "You have already registered. Please login.",
				Code:  "ALREADY_REGISTERED",
			})
		case errors.Is(err, services.ErrMemberInactive):
			c.JSON(http.StatusForbidden, response.ErrorResponse{
				Error: "Your membership is inactive. Please contact your admin.",
				Code:  "MEMBER_INACTIVE",
			})
		default:
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{
				Error: "Failed to initiate registration",
				Code:  "INTERNAL_ERROR",
			})
		}
		return
	}

	// Build response
	flatNumber := ""
	wing := ""
	if member.Flat != nil {
		flatNumber = member.Flat.FlatNumber
		if member.Flat.Wing != nil {
			wing = member.Flat.Wing.Name
		}
	}

	c.JSON(http.StatusOK, response.InitiateRegistrationResponse{
		Message: "OTP sent to your registered mobile number",
		Member: response.MemberInfoResponse{
			ID:          member.ID.String(),
			Name:        member.Name,
			Mobile:      maskMobile(member.Mobile),
			FlatNumber:  flatNumber,
			Wing:        wing,
			Role:        string(member.Role),
			Designation: member.Designation,
		},
		OTPExpiry: 300, // 5 minutes
	})
}

// VerifyOTP verifies the OTP
// @Summary Verify OTP
// @Description Verify OTP for registration
// @Tags Registration
// @Accept json
// @Produce json
// @Param request body request.VerifyOTPRequest true "OTP verification"
// @Success 200 {object} response.VerifyOTPResponse
// @Failure 400 {object} response.ErrorResponse
// @Router /api/v1/registration/verify-otp [post]
func (h *RegistrationHandler) VerifyOTP(c *gin.Context) {
	var req request.VerifyOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{
			Error: "Invalid request body",
			Code:  "VALIDATION_ERROR",
		})
		return
	}

	err := h.registrationService.VerifyOTP(c.Request.Context(), req.Mobile, req.OTP)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrOTPNotFound):
			c.JSON(http.StatusNotFound, response.ErrorResponse{
				Error: "No OTP found. Please request a new one.",
				Code:  "OTP_NOT_FOUND",
			})
		case errors.Is(err, services.ErrOTPExpired):
			c.JSON(http.StatusGone, response.ErrorResponse{
				Error: "OTP has expired. Please request a new one.",
				Code:  "OTP_EXPIRED",
			})
		case errors.Is(err, services.ErrOTPMaxAttempts):
			c.JSON(http.StatusTooManyRequests, response.ErrorResponse{
				Error: "Too many failed attempts. Please request a new OTP.",
				Code:  "OTP_MAX_ATTEMPTS",
			})
		case errors.Is(err, services.ErrInvalidOTP):
			c.JSON(http.StatusUnauthorized, response.ErrorResponse{
				Error: "Invalid OTP. Please try again.",
				Code:  "INVALID_OTP",
			})
		default:
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{
				Error: "Failed to verify OTP",
				Code:  "INTERNAL_ERROR",
			})
		}
		return
	}

	c.JSON(http.StatusOK, response.VerifyOTPResponse{
		Message:  "OTP verified successfully",
		Verified: true,
	})
}

// CompleteRegistration completes the registration
// @Summary Complete Registration
// @Description Create credentials after OTP verification
// @Tags Registration
// @Accept json
// @Produce json
// @Param request body request.CompleteRegistrationRequest true "Registration credentials"
// @Success 201 {object} response.RegistrationCompleteResponse
// @Failure 400 {object} response.ErrorResponse
// @Router /api/v1/registration/complete [post]
func (h *RegistrationHandler) CompleteRegistration(c *gin.Context) {
	var req request.CompleteRegistrationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{
			Error: "Invalid request body. Password must be at least 8 characters.",
			Code:  "VALIDATION_ERROR",
		})
		return
	}

	user, member, err := h.registrationService.CompleteRegistration(
		c.Request.Context(),
		req.Mobile,
		req.Email,
		req.Password,
	)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrMemberNotFound):
			c.JSON(http.StatusNotFound, response.ErrorResponse{
				Error: "Member not found",
				Code:  "MEMBER_NOT_FOUND",
			})
		case errors.Is(err, services.ErrMemberAlreadyRegistered):
			c.JSON(http.StatusConflict, response.ErrorResponse{
				Error: "Already registered. Please login.",
				Code:  "ALREADY_REGISTERED",
			})
		case errors.Is(err, services.ErrEmailAlreadyExists):
			c.JSON(http.StatusConflict, response.ErrorResponse{
				Error: "Email already in use. Please use a different email.",
				Code:  "EMAIL_EXISTS",
			})
		default:
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{
				Error: "Failed to complete registration",
				Code:  "INTERNAL_ERROR",
			})
		}
		return
	}

	// Build flat info
	flatNumber := ""
	if member.Flat != nil {
		flatNumber = member.Flat.FlatNumber
	}

	c.JSON(http.StatusCreated, response.RegistrationCompleteResponse{
		Message: "Registration successful! You can now login.",
		User: response.UserResponse{
			ID:          user.ID.String(),
			Name:        member.Name,
			Email:       user.Email,
			Phone:       user.Mobile,
			Role:        string(member.Role),
			Designation: member.Designation,
			FlatID:      member.FlatID.String(),
			FlatNumber:  flatNumber,
			Permissions: []string{}, // Will be filled on login
			IsActive:    user.IsActive,
		},
	})
}

// ResendOTP resends OTP
// @Summary Resend OTP
// @Description Request a new OTP
// @Tags Registration
// @Accept json
// @Produce json
// @Param request body request.ResendOTPRequest true "Mobile number"
// @Success 200 {object} response.MessageResponse
// @Failure 400 {object} response.ErrorResponse
// @Router /api/v1/registration/resend-otp [post]
func (h *RegistrationHandler) ResendOTP(c *gin.Context) {
	var req request.ResendOTPRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{
			Error: "Invalid request body",
			Code:  "VALIDATION_ERROR",
		})
		return
	}

	err := h.registrationService.ResendOTP(c.Request.Context(), req.Mobile)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrMemberNotFound):
			c.JSON(http.StatusNotFound, response.ErrorResponse{
				Error: "Mobile number not registered",
				Code:  "MEMBER_NOT_FOUND",
			})
		case errors.Is(err, services.ErrMemberAlreadyRegistered):
			c.JSON(http.StatusConflict, response.ErrorResponse{
				Error: "Already registered. Please login.",
				Code:  "ALREADY_REGISTERED",
			})
		default:
			c.JSON(http.StatusInternalServerError, response.ErrorResponse{
				Error: "Failed to resend OTP",
				Code:  "INTERNAL_ERROR",
			})
		}
		return
	}

	c.JSON(http.StatusOK, response.MessageResponse{
		Message: "New OTP sent to your mobile",
	})
}

// maskMobile masks mobile number for privacy
func maskMobile(mobile string) string {
	if len(mobile) < 6 {
		return mobile
	}
	return mobile[:2] + "****" + mobile[len(mobile)-4:]
}
