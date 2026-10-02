package handlers

import (
	"fmt"
	"math"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type GSTInvoiceHandler struct {
	billRepo *repositories.BillRepository
	db       *gorm.DB
}

func NewGSTInvoiceHandler(billRepo *repositories.BillRepository, db *gorm.DB) *GSTInvoiceHandler {
	return &GSTInvoiceHandler{billRepo: billRepo, db: db}
}

// getSetting reads a society setting with fallback default.
func (h *GSTInvoiceHandler) getSetting(key, fallback string) string {
	var s models.SocietySetting
	if err := h.db.Where("key = ?", key).First(&s).Error; err == nil {
		return s.Value
	}
	return fallback
}

// GetInvoice returns a GST-compliant invoice view for a bill.
func (h *GSTInvoiceHandler) GetInvoice(c *gin.Context) {
	billID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid bill ID", Code: "INVALID_ID"})
		return
	}

	actor := middleware.GetActor(c)
	bill, err := h.billRepo.GetByID(actor, billID)
	if err != nil {
		writeRepoError(c, err)
		return
	}

	// Load society settings
	gstin := h.getSetting(models.SettingGSTIN, "")
	pan := h.getSetting(models.SettingPAN, "")
	societyName := h.getSetting(models.SettingSocietyName, "Aangan Housing Society.")
	societyAddr := h.getSetting(models.SettingSocietyAddr, "Bhandup (W), Mumbai - 400078")
	sacCode := h.getSetting(models.SettingSACCode, "9972")
	gstRateStr := h.getSetting(models.SettingGSTRate, "18")
	thresholdStr := h.getSetting(models.SettingGSTThreshold, "7500")
	invoicePrefix := h.getSetting(models.SettingInvoicePrefix, "INV")

	gstRate, _ := strconv.ParseFloat(gstRateStr, 64)
	threshold, _ := strconv.ParseFloat(thresholdStr, 64)

	// Calculate base amount (excluding arrears and interest)
	baseAmount := bill.TotalAmount - bill.ArrearAmount - bill.InterestAmount

	// GST applies only if monthly maintenance > threshold per flat
	gstApplicable := baseAmount > threshold
	var cgst, sgst, totalGST, grandTotal float64

	if gstApplicable && gstRate > 0 {
		// Base amount is inclusive, calculate GST on top
		cgst = round2(baseAmount * (gstRate / 2) / 100)
		sgst = round2(baseAmount * (gstRate / 2) / 100)
		totalGST = cgst + sgst
		grandTotal = bill.TotalAmount + totalGST
	} else {
		grandTotal = bill.TotalAmount
	}

	// Build line items for invoice
	type invoiceLine struct {
		Description   string  `json:"description"`
		DescriptionMr string  `json:"descriptionMr"`
		SACCode       string  `json:"sacCode"`
		Amount        float64 `json:"amount"`
	}

	var lines []invoiceLine
	for _, li := range bill.LineItems {
		if li.IsArrear || li.IsInterest {
			continue // arrears/interest shown separately
		}
		lines = append(lines, invoiceLine{
			Description:   li.Label,
			DescriptionMr: li.LabelMr,
			SACCode:       sacCode,
			Amount:        li.Amount,
		})
	}

	// Generate invoice number from bill number
	invoiceNo := fmt.Sprintf("%s/%s/%s", invoicePrefix, bill.BillingPeriod, bill.BillNo)

	c.JSON(http.StatusOK, gin.H{
		// Society details
		"societyName":    societyName,
		"societyAddress": societyAddr,
		"gstin":          gstin,
		"pan":            pan,

		// Invoice header
		"invoiceNo":     invoiceNo,
		"invoiceDate":   bill.IssueDate.Format("2006-01-02"),
		"billingPeriod": bill.BillingPeriod,
		"dueDate":       bill.DueDate.Format("2006-01-02"),

		// Member / flat
		"memberName": bill.Member.Name,
		"flatNumber": bill.Flat.FlatNumber,

		// Line items
		"lineItems":   lines,
		"baseAmount":  baseAmount,
		"arrears":     bill.ArrearAmount,
		"interest":    bill.InterestAmount,
		"subTotal":    bill.TotalAmount,

		// GST
		"gstApplicable": gstApplicable,
		"sacCode":       sacCode,
		"gstRate":       gstRate,
		"cgst":          cgst,
		"sgst":          sgst,
		"totalGST":      totalGST,
		"grandTotal":    grandTotal,

		// Payment
		"amountPaid": bill.AmountPaid,
		"balanceDue": grandTotal - bill.AmountPaid,
		"status":     bill.Status,
	})
}

// ListSettings returns all society settings (admin only).
func (h *GSTInvoiceHandler) ListSettings(c *gin.Context) {
	actor := middleware.GetActor(c)
	if !actor.IsAdmin() {
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: "Admin only", Code: "FORBIDDEN"})
		return
	}
	var settings []models.SocietySetting
	h.db.Find(&settings)
	c.JSON(http.StatusOK, gin.H{"settings": settings})
}

type upsertSettingReq struct {
	Key   string `json:"key" binding:"required"`
	Value string `json:"value" binding:"required"`
}

// UpsertSetting creates or updates a society setting.
func (h *GSTInvoiceHandler) UpsertSetting(c *gin.Context) {
	actor := middleware.GetActor(c)
	if !actor.IsAdmin() {
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: "Admin only", Code: "FORBIDDEN"})
		return
	}
	var req upsertSettingReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	var existing models.SocietySetting
	if err := h.db.Where("key = ?", req.Key).First(&existing).Error; err == nil {
		h.db.Model(&existing).Update("value", req.Value)
	} else {
		h.db.Create(&models.SocietySetting{Key: req.Key, Value: req.Value})
	}
	c.JSON(http.StatusOK, gin.H{"message": "Setting saved"})
}

func round2(v float64) float64 {
	return math.Round(v*100) / 100
}
