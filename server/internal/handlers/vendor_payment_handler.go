package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type VendorPaymentHandler struct {
	repo *repositories.VendorPaymentRepository
}

func NewVendorPaymentHandler(repo *repositories.VendorPaymentRepository) *VendorPaymentHandler {
	return &VendorPaymentHandler{repo: repo}
}

func (h *VendorPaymentHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"payments": rows})
}

func (h *VendorPaymentHandler) GetByID(c *gin.Context) {
	actor := middleware.GetActor(c)
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID"})
		return
	}
	vp, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, vp)
}

type createVendorPaymentReq struct {
	VendorID         string  `json:"vendorId" binding:"required"`
	PaymentDate      string  `json:"paymentDate" binding:"required"`
	GrossAmount      float64 `json:"grossAmount" binding:"required"`
	Narration        string  `json:"narration"`
	NarrationMr      string  `json:"narrationMr"`
	PaymentMode      string  `json:"paymentMode"`
	Reference        string  `json:"reference"`
	ExpenseAccountID string  `json:"expenseAccountId"`
}

func (h *VendorPaymentHandler) Create(c *gin.Context) {
	actor := middleware.GetActor(c)
	var req createVendorPaymentReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	vendorID, err := uuid.Parse(req.VendorID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid vendor ID"})
		return
	}

	payDate, err := time.Parse("2006-01-02", req.PaymentDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid payment date"})
		return
	}

	vp := &models.VendorPayment{
		VendorID:    vendorID,
		PaymentDate: payDate,
		GrossAmount: req.GrossAmount,
		Narration:   req.Narration,
		NarrationMr: req.NarrationMr,
		PaymentMode: req.PaymentMode,
	}
	if vp.PaymentMode == "" {
		vp.PaymentMode = "BANK"
	}
	vp.Reference = req.Reference

	if req.ExpenseAccountID != "" {
		id, err := uuid.Parse(req.ExpenseAccountID)
		if err == nil {
			vp.ExpenseAccountID = &id
		}
	}

	if err := h.repo.Create(actor, vp); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, vp)
}

type markTDSDepositedReq struct {
	ChallanNo   string `json:"challanNo" binding:"required"`
	DepositDate string `json:"depositDate" binding:"required"`
}

func (h *VendorPaymentHandler) MarkTDSDeposited(c *gin.Context) {
	actor := middleware.GetActor(c)
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID"})
		return
	}

	var req markTDSDepositedReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	depositDate, err := time.Parse("2006-01-02", req.DepositDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid deposit date"})
		return
	}

	if err := h.repo.MarkTDSDeposited(actor, id, req.ChallanNo, depositDate); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "TDS marked as deposited"})
}

func (h *VendorPaymentHandler) TDSSummary(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.GetTDSSummary(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"summary": rows})
}

func (h *VendorPaymentHandler) PendingTDS(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.GetPendingTDSPayments(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"payments": rows})
}
