package handlers

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
	"sainath-society/internal/services"
)

type EmergencyContactHandler struct {
	repo     *repositories.EmergencyContactRepository
	notifier *services.Notifier
}

func NewEmergencyContactHandler(repo *repositories.EmergencyContactRepository, notifier *services.Notifier) *EmergencyContactHandler {
	return &EmergencyContactHandler{repo: repo, notifier: notifier}
}

func (h *EmergencyContactHandler) List(c *gin.Context) {
	contacts, err := h.repo.List()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	committee, err := h.repo.ListCommitteeMembers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"contacts":  contacts,
		"committee": committee,
		"count":     len(contacts),
	})
}

type createEmergencyContactReq struct {
	Name      string                  `json:"name" binding:"required,max=100"`
	NameMr    string                  `json:"nameMr,omitempty"`
	Category  models.ContactCategory  `json:"category" binding:"required"`
	Phone     string                  `json:"phone" binding:"required,max=20"`
	AltPhone  string                  `json:"altPhone,omitempty"`
	Role      string                  `json:"role,omitempty"`
	RoleMr    string                  `json:"roleMr,omitempty"`
	SortOrder int                     `json:"sortOrder,omitempty"`
}

func (h *EmergencyContactHandler) Create(c *gin.Context) {
	var req createEmergencyContactReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	ec := &models.EmergencyContact{
		Name:      req.Name,
		NameMr:    req.NameMr,
		Category:  req.Category,
		Phone:     req.Phone,
		AltPhone:  req.AltPhone,
		Role:      req.Role,
		RoleMr:    req.RoleMr,
		SortOrder: req.SortOrder,
	}
	if err := h.repo.Create(actor, ec); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, ec)
}

type updateEmergencyContactReq struct {
	Name      *string                  `json:"name,omitempty"`
	NameMr    *string                  `json:"nameMr,omitempty"`
	Category  *models.ContactCategory  `json:"category,omitempty"`
	Phone     *string                  `json:"phone,omitempty"`
	AltPhone  *string                  `json:"altPhone,omitempty"`
	Role      *string                  `json:"role,omitempty"`
	RoleMr    *string                  `json:"roleMr,omitempty"`
	SortOrder *int                     `json:"sortOrder,omitempty"`
}

func (h *EmergencyContactHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req updateEmergencyContactReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	updates := map[string]interface{}{}
	if req.Name != nil {
		updates["name"] = *req.Name
	}
	if req.NameMr != nil {
		updates["name_mr"] = *req.NameMr
	}
	if req.Category != nil {
		updates["category"] = *req.Category
	}
	if req.Phone != nil {
		updates["phone"] = *req.Phone
	}
	if req.AltPhone != nil {
		updates["alt_phone"] = *req.AltPhone
	}
	if req.Role != nil {
		updates["role"] = *req.Role
	}
	if req.RoleMr != nil {
		updates["role_mr"] = *req.RoleMr
	}
	if req.SortOrder != nil {
		updates["sort_order"] = *req.SortOrder
	}
	if err := h.repo.Update(actor, id, updates); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Updated"})
}

func (h *EmergencyContactHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Delete(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Deleted"})
}

// ─── SOS Broadcast ─────────────────────────────────────────────

type sosReq struct {
	Type    string `json:"type" binding:"required"` // FIRE, MEDICAL, SECURITY, WATER, GAS, OTHER
	Message string `json:"message"`
	FlatNo  string `json:"flatNo"`
}

func (h *EmergencyContactHandler) SOS(c *gin.Context) {
	var req sosReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)

	// Build alert message
	flat := req.FlatNo
	if flat == "" {
		flat = "Unknown"
	}
	subject := fmt.Sprintf("SOS ALERT: %s — Flat %s", req.Type, flat)
	body := fmt.Sprintf("Emergency SOS from Flat %s!\nType: %s\n%s\nPlease respond immediately.", flat, req.Type, req.Message)
	bodyMr := fmt.Sprintf("आपत्कालीन SOS — फ्लॅट %s!\nप्रकार: %s\n%s\nकृपया तातडीने प्रतिसाद द्या.", flat, req.Type, req.Message)

	// Broadcast to all members
	go h.notifier.NotifyAllMembers(subject, body, bodyMr, "SOS_ALERT", "emergency", nil)

	_ = actor // logged for audit
	c.JSON(http.StatusOK, gin.H{"message": "SOS alert sent to all members", "type": req.Type})
}
