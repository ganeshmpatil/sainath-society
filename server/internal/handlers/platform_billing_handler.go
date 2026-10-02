package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/services"
)

type PlatformBillingHandler struct {
	svc *services.PlatformBillingService
}

func NewPlatformBillingHandler(svc *services.PlatformBillingService) *PlatformBillingHandler {
	return &PlatformBillingHandler{svc: svc}
}

// ─── Billing Configs ────────────────────────────────────────────────────────

func (h *PlatformBillingHandler) ListConfigs(c *gin.Context) {
	configs, err := h.svc.ListConfigs()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to load configs", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"configs": configs})
}

func (h *PlatformBillingHandler) GetConfig(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	cfg, err := h.svc.GetConfig(id)
	if err != nil {
		c.JSON(http.StatusNotFound, response.ErrorResponse{Error: "Config not found", Code: "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"config": cfg})
}

func (h *PlatformBillingHandler) UpdateConfig(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}

	var body struct {
		RatePerFlat   *float64 `json:"ratePerFlat"`
		BillingCycle  *string  `json:"billingCycle"`
		BillingDay    *int     `json:"billingDay"`
		DueDays       *int     `json:"dueDays"`
		GraceDays     *int     `json:"graceDays"`
		InterestRate  *float64 `json:"interestRate"`
		GSTApplicable *bool    `json:"gstApplicable"`
		GSTNumber     *string  `json:"gstNumber"`
		IsActive      *bool    `json:"isActive"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid request body", Code: "VALIDATION_ERROR"})
		return
	}

	updates := make(map[string]interface{})
	if body.RatePerFlat != nil {
		updates["rate_per_flat"] = *body.RatePerFlat
	}
	if body.BillingCycle != nil {
		updates["billing_cycle"] = *body.BillingCycle
	}
	if body.BillingDay != nil {
		updates["billing_day"] = *body.BillingDay
	}
	if body.DueDays != nil {
		updates["due_days"] = *body.DueDays
	}
	if body.GraceDays != nil {
		updates["grace_days"] = *body.GraceDays
	}
	if body.InterestRate != nil {
		updates["interest_rate"] = *body.InterestRate
	}
	if body.GSTApplicable != nil {
		updates["gst_applicable"] = *body.GSTApplicable
	}
	if body.GSTNumber != nil {
		updates["gst_number"] = *body.GSTNumber
	}
	if body.IsActive != nil {
		updates["is_active"] = *body.IsActive
	}

	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "No fields to update", Code: "VALIDATION_ERROR"})
		return
	}

	if err := h.svc.UpdateConfig(id, updates); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to update config", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Config updated"})
}

// ─── Invoices ───────────────────────────────────────────────────────────────

func (h *PlatformBillingHandler) ListInvoices(c *gin.Context) {
	var societyID *uuid.UUID
	if s := c.Query("societyId"); s != "" {
		id, err := uuid.Parse(s)
		if err == nil {
			societyID = &id
		}
	}

	var status *string
	if s := c.Query("status"); s != "" {
		status = &s
	}

	var period *string
	if s := c.Query("period"); s != "" {
		period = &s
	}

	invoices, err := h.svc.ListInvoices(societyID, status, period)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to load invoices", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"invoices": invoices})
}

func (h *PlatformBillingHandler) GetInvoice(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	inv, err := h.svc.GetInvoice(id)
	if err != nil {
		c.JSON(http.StatusNotFound, response.ErrorResponse{Error: "Invoice not found", Code: "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"invoice": inv})
}

func (h *PlatformBillingHandler) MarkPaid(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}

	var body struct {
		Amount      float64 `json:"amount" binding:"required"`
		PaymentMode string  `json:"paymentMode" binding:"required"`
		PaymentRef  string  `json:"paymentRef"`
		Notes       string  `json:"notes"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Amount and payment mode are required", Code: "VALIDATION_ERROR"})
		return
	}

	if err := h.svc.MarkPaid(id, body.Amount, body.PaymentMode, body.PaymentRef, body.Notes); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to mark paid", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Invoice marked as paid"})
}

// ─── Manual Billing Run ─────────────────────────────────────────────────────

func (h *PlatformBillingHandler) RunBilling(c *gin.Context) {
	if err := h.svc.RunManualBilling(); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Billing run failed: " + err.Error(), Code: "BILLING_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Billing run completed"})
}

// ─── Audit Logs ─────────────────────────────────────────────────────────────

func (h *PlatformBillingHandler) ListAudits(c *gin.Context) {
	audits, err := h.svc.ListAudits(100)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to load audits", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"audits": audits})
}

// ─── Summary ────────────────────────────────────────────────────────────────

func (h *PlatformBillingHandler) Summary(c *gin.Context) {
	summary, err := h.svc.GetSummary()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to load summary", Code: "INTERNAL_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"summary": summary})
}
