package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type AMCContractHandler struct {
	repo *repositories.AMCContractRepository
}

func NewAMCContractHandler(repo *repositories.AMCContractRepository) *AMCContractHandler {
	return &AMCContractHandler{repo: repo}
}

func (h *AMCContractHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"contracts": rows, "count": len(rows)})
}

func (h *AMCContractHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	contract, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, contract)
}

type createContractReq struct {
	VendorID       uuid.UUID `json:"vendorId" binding:"required"`
	ServiceType    string    `json:"serviceType" binding:"required"`
	Description    string    `json:"description"`
	DescriptionMr  string    `json:"descriptionMr"`
	ContractAmount float64   `json:"contractAmount" binding:"required,gt=0"`
	PaymentTerms   string    `json:"paymentTerms"`
	StartDate      string    `json:"startDate" binding:"required"`
	EndDate        string    `json:"endDate" binding:"required"`
	ReminderDays   int       `json:"reminderDays"`
	Notes          string    `json:"notes"`
}

func (h *AMCContractHandler) Create(c *gin.Context) {
	var req createContractReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	startDate, _ := time.Parse("2006-01-02", req.StartDate)
	endDate, _ := time.Parse("2006-01-02", req.EndDate)
	if req.ReminderDays == 0 {
		req.ReminderDays = 30
	}
	actor := middleware.GetActor(c)
	contract := &models.AMCContract{
		VendorID:       req.VendorID,
		ServiceType:    models.ServiceType(req.ServiceType),
		Description:    req.Description,
		DescriptionMr:  req.DescriptionMr,
		ContractAmount: req.ContractAmount,
		PaymentTerms:   req.PaymentTerms,
		StartDate:      startDate,
		EndDate:        endDate,
		ReminderDays:   req.ReminderDays,
		Status:         models.ContractActive,
		Notes:          req.Notes,
	}
	if err := h.repo.Create(actor, contract); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, contract)
}

func (h *AMCContractHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Update(actor, id, updates); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Contract updated"})
}

func (h *AMCContractHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Delete(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Contract deleted"})
}

func (h *AMCContractHandler) Summary(c *gin.Context) {
	active, expiring, expired, total, err := h.repo.Summary()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "SUMMARY_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"activeContracts":   active,
		"expiringSoon":      expiring,
		"expiredContracts":  expired,
		"totalContractValue": total,
	})
}

func (h *AMCContractHandler) ExpiringSoon(c *gin.Context) {
	rows, err := h.repo.GetExpiringSoon(30)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "FETCH_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"contracts": rows, "count": len(rows)})
}

// ─── Service Logs ──────────────────────────────────────────────

type logServiceReq struct {
	ServiceDate    string `json:"serviceDate" binding:"required"`
	Description    string `json:"description" binding:"required"`
	TechnicianName string `json:"technicianName"`
	Rating         int    `json:"rating"`
	Notes          string `json:"notes"`
}

func (h *AMCContractHandler) LogService(c *gin.Context) {
	contractID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req logServiceReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	serviceDate, _ := time.Parse("2006-01-02", req.ServiceDate)
	actor := middleware.GetActor(c)
	log := &models.ServiceLog{
		ContractID:     contractID,
		ServiceDate:    serviceDate,
		Description:    req.Description,
		TechnicianName: req.TechnicianName,
		Rating:         req.Rating,
		Notes:          req.Notes,
	}
	if err := h.repo.LogService(actor, log); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, log)
}

func (h *AMCContractHandler) ListServiceLogs(c *gin.Context) {
	contractID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	rows, err := h.repo.ListServiceLogs(contractID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "FETCH_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"serviceLogs": rows, "count": len(rows)})
}
