package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type TenantHandler struct {
	repo *repositories.TenantRepository
}

func NewTenantHandler(repo *repositories.TenantRepository) *TenantHandler {
	return &TenantHandler{repo: repo}
}

type createTenantReq struct {
	Name               string     `json:"name" binding:"required,max=100"`
	Mobile             string     `json:"mobile" binding:"required,max=15"`
	Email              string     `json:"email,omitempty"`
	AadhaarLast4       string     `json:"aadhaarLast4,omitempty"`
	AgreementStart     *time.Time `json:"agreementStart,omitempty"`
	AgreementEnd       *time.Time `json:"agreementEnd,omitempty"`
	MonthlyRent        float64    `json:"monthlyRent,omitempty"`
	Deposit            float64    `json:"deposit,omitempty"`
	FamilyCount        int        `json:"familyCount,omitempty"`
	VerificationDocURL string     `json:"verificationDocUrl,omitempty"`
}

func (h *TenantHandler) Create(c *gin.Context) {
	var req createTenantReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	t := &models.Tenant{
		Name: req.Name, Mobile: req.Mobile, Email: req.Email,
		AadhaarLast4:       req.AadhaarLast4,
		AgreementStart:     req.AgreementStart,
		AgreementEnd:       req.AgreementEnd,
		MonthlyRent:        req.MonthlyRent,
		Deposit:            req.Deposit,
		FamilyCount:        req.FamilyCount,
		VerificationDocURL: req.VerificationDocURL,
	}
	if err := h.repo.Create(actor, t); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, t)
}

func (h *TenantHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListForActor(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"tenants": rows, "count": len(rows)})
}

func (h *TenantHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	t, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, t)
}

func (h *TenantHandler) Approve(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Approve(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Tenant approved"})
}

type recordMovementReq struct {
	MovementType   models.MovementType `json:"movementType" binding:"required"`
	ScheduledAt    time.Time           `json:"scheduledAt" binding:"required"`
	ActualAt       *time.Time          `json:"actualAt,omitempty"`
	VehicleDetails string              `json:"vehicleDetails,omitempty"`
	Notes          string              `json:"notes,omitempty"`
}

func (h *TenantHandler) RecordMovement(c *gin.Context) {
	tenantID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req recordMovementReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	m := &models.TenantMovement{
		TenantID:       tenantID,
		MovementType:   req.MovementType,
		ScheduledAt:    req.ScheduledAt,
		ActualAt:       req.ActualAt,
		VehicleDetails: req.VehicleDetails,
		Notes:          req.Notes,
	}
	if err := h.repo.RecordMovement(actor, m); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, m)
}

func (h *TenantHandler) ListMovements(c *gin.Context) {
	tenantID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListMovements(actor, tenantID)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"movements": rows, "count": len(rows)})
}
