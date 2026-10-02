package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/models"
	"sainath-society/internal/services"
)

type PlatformHandler struct {
	svc *services.PlatformService
}

func NewPlatformHandler(svc *services.PlatformService) *PlatformHandler {
	return &PlatformHandler{svc: svc}
}

// ─── Auth ───────────────────────────────────────────────────────────────────

func (h *PlatformHandler) Login(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid request", Code: "VALIDATION_ERROR"})
		return
	}
	token, admin, err := h.svc.LoginAdmin(req.Email, req.Password)
	if err != nil {
		c.JSON(http.StatusUnauthorized, response.ErrorResponse{Error: "Invalid credentials", Code: "INVALID_CREDENTIALS"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"accessToken": token,
		"admin":       gin.H{"id": admin.ID, "name": admin.Name, "email": admin.Email},
	})
}

func (h *PlatformHandler) GetMe(c *gin.Context) {
	adminID := getPlatformAdminID(c)
	if adminID == uuid.Nil {
		c.JSON(http.StatusUnauthorized, response.ErrorResponse{Error: "Not authenticated", Code: "UNAUTHENTICATED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"adminId": adminID, "role": "PLATFORM_ADMIN"})
}

// ─── Dashboard ──────────────────────────────────────────────────────────────

func (h *PlatformHandler) Dashboard(c *gin.Context) {
	stats, err := h.svc.GetDashboardStats()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to load stats", Code: "INTERNAL_ERROR"})
		return
	}

	// Recent pending requests
	pending := models.OnboardingPending
	recentRequests, _ := h.svc.ListRequests(&pending)

	c.JSON(http.StatusOK, gin.H{
		"stats":          stats,
		"recentRequests": recentRequests,
	})
}

// ─── Onboarding Requests ────────────────────────────────────────────────────

func (h *PlatformHandler) SubmitRequest(c *gin.Context) {
	var input services.SubmitOnboardingInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid request body", Code: "VALIDATION_ERROR"})
		return
	}

	// Run auto-validation
	validation := h.svc.ValidateRequest(&input)

	req, err := h.svc.SubmitOnboardingRequest(&input)
	if err != nil {
		if errors.Is(err, services.ErrDuplicateRegNumber) {
			c.JSON(http.StatusConflict, response.ErrorResponse{Error: err.Error(), Code: "DUPLICATE_REG_NUMBER"})
			return
		}
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to submit request", Code: "INTERNAL_ERROR"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"request":    req,
		"validation": validation,
	})
}

func (h *PlatformHandler) ListRequests(c *gin.Context) {
	var status *models.OnboardingStatus
	if s := c.Query("status"); s != "" {
		st := models.OnboardingStatus(s)
		status = &st
	}

	requests, err := h.svc.ListRequests(status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to list requests", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"requests": requests})
}

func (h *PlatformHandler) GetRequest(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	req, err := h.svc.GetRequest(id)
	if err != nil {
		c.JSON(http.StatusNotFound, response.ErrorResponse{Error: "Request not found", Code: "NOT_FOUND"})
		return
	}

	// Include auto-validation results
	input := &services.SubmitOnboardingInput{
		RegistrationNumber: req.RegistrationNumber,
		City:               req.City,
		PinCode:            req.PinCode,
	}
	validation := h.svc.ValidateRequest(input)

	c.JSON(http.StatusOK, gin.H{
		"request":    req,
		"validation": validation,
	})
}

func (h *PlatformHandler) ApproveRequest(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	adminID := getPlatformAdminID(c)

	var body struct {
		Notes string `json:"notes"`
	}
	c.ShouldBindJSON(&body)

	society, err := h.svc.ApproveRequest(id, adminID, body.Notes)
	if err != nil {
		if errors.Is(err, services.ErrRequestNotPending) {
			c.JSON(http.StatusConflict, response.ErrorResponse{Error: err.Error(), Code: "NOT_PENDING"})
			return
		}
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to approve", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"society": society, "message": "Society approved and provisioned"})
}

func (h *PlatformHandler) RejectRequest(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	adminID := getPlatformAdminID(c)

	var body struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Reason is required", Code: "VALIDATION_ERROR"})
		return
	}

	if err := h.svc.RejectRequest(id, adminID, body.Reason); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to reject", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Request rejected"})
}

func (h *PlatformHandler) RequestMoreInfo(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	adminID := getPlatformAdminID(c)

	var body struct {
		Message string `json:"message" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Message is required", Code: "VALIDATION_ERROR"})
		return
	}

	if err := h.svc.RequestInfo(id, adminID, body.Message); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to request info", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Info request sent"})
}

// ─── Societies ──────────────────────────────────────────────────────────────

func (h *PlatformHandler) ListSocieties(c *gin.Context) {
	var status *models.SocietyStatus
	if s := c.Query("status"); s != "" {
		st := models.SocietyStatus(s)
		status = &st
	}

	societies, err := h.svc.ListSocieties(status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to list societies", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"societies": societies})
}

func (h *PlatformHandler) GetSociety(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}

	society, err := h.svc.GetSociety(id)
	if err != nil {
		c.JSON(http.StatusNotFound, response.ErrorResponse{Error: "Society not found", Code: "NOT_FOUND"})
		return
	}

	usage, _ := h.svc.GetSocietyUsageStats(id)

	c.JSON(http.StatusOK, gin.H{
		"society": society,
		"usage":   usage,
	})
}

func (h *PlatformHandler) SuspendSociety(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	adminID := getPlatformAdminID(c)

	var body struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Reason is required", Code: "VALIDATION_ERROR"})
		return
	}

	if err := h.svc.SuspendSociety(id, adminID, body.Reason); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to suspend", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Society suspended"})
}

func (h *PlatformHandler) ActivateSociety(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	adminID := getPlatformAdminID(c)

	if err := h.svc.ActivateSociety(id, adminID); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to activate", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Society activated"})
}

// ─── Audit Log ──────────────────────────────────────────────────────────────

func (h *PlatformHandler) AuditLog(c *gin.Context) {
	logs, err := h.svc.ListAuditLogs(100)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to load audit log", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"logs": logs})
}

// ─── Helpers ────────────────────────────────────────────────────────────────

// getPlatformAdminID extracts the admin ID from the JWT set by AuthMiddleware.
// Platform admins have role "PLATFORM_ADMIN" in their JWT.
func getPlatformAdminID(c *gin.Context) uuid.UUID {
	idStr := c.GetString("userID")
	if idStr == "" {
		return uuid.Nil
	}
	id, err := uuid.Parse(idStr)
	if err != nil {
		return uuid.Nil
	}
	return id
}
