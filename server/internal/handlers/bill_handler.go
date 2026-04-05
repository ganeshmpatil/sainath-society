package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/repositories"
)

type BillHandler struct {
	repo *repositories.BillRepository
}

func NewBillHandler(repo *repositories.BillRepository) *BillHandler {
	return &BillHandler{repo: repo}
}

type generateBillsReq struct {
	BillingPeriod     string    `json:"billingPeriod" binding:"required"` // e.g. "2026-04"
	DueDate           time.Time `json:"dueDate" binding:"required"`
	MaintenanceCharge float64   `json:"maintenanceCharge" binding:"required,gt=0"`
	SinkingFund       float64   `json:"sinkingFund,omitempty"`
	RepairFund        float64   `json:"repairFund,omitempty"`
	WaterCharge       float64   `json:"waterCharge,omitempty"`
	OtherCharges      float64   `json:"otherCharges,omitempty"`
}

// Generate creates maintenance bills for every active flat in one batch.
func (h *BillHandler) Generate(c *gin.Context) {
	var req generateBillsReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	created, skipped, err := h.repo.GenerateForPeriod(actor, repositories.BillGenerationRequest{
		BillingPeriod:     req.BillingPeriod,
		DueDate:           req.DueDate,
		MaintenanceCharge: req.MaintenanceCharge,
		SinkingFund:       req.SinkingFund,
		RepairFund:        req.RepairFund,
		WaterCharge:       req.WaterCharge,
		OtherCharges:      req.OtherCharges,
	})
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"created": created, "skipped": skipped,
		"billingPeriod": req.BillingPeriod,
	})
}

func (h *BillHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	var flatFilter *uuid.UUID
	if s := c.Query("flatId"); s != "" && actor.IsAdmin() {
		if id, err := uuid.Parse(s); err == nil {
			flatFilter = &id
		}
	}
	rows, err := h.repo.ListForActor(actor, flatFilter, c.Query("period"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"bills": rows, "count": len(rows)})
}

func (h *BillHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	bill, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, bill)
}

func (h *BillHandler) PendingDues(c *gin.Context) {
	actor := middleware.GetActor(c)
	var memberFilter *uuid.UUID
	if s := c.Query("memberId"); s != "" && actor.IsAdmin() {
		if id, err := uuid.Parse(s); err == nil {
			memberFilter = &id
		}
	}
	total, count, err := h.repo.PendingDues(actor, memberFilter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "DUES_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"pendingAmount": total, "unpaidCount": count})
}

type markBillPaidReq struct {
	Amount float64    `json:"amount" binding:"required,gt=0"`
	TxnID  *uuid.UUID `json:"txnId,omitempty"`
}

func (h *BillHandler) MarkPaid(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req markBillPaidReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.MarkPaid(actor, id, req.Amount, req.TxnID); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Marked paid"})
}
