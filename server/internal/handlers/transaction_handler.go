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

type TransactionHandler struct {
	repo *repositories.TransactionRepository
}

func NewTransactionHandler(repo *repositories.TransactionRepository) *TransactionHandler {
	return &TransactionHandler{repo: repo}
}

type createTxnReq struct {
	MemberID      *uuid.UUID                  `json:"memberId,omitempty"` // admin-only
	FlatID        *uuid.UUID                  `json:"flatId,omitempty"`
	TxnType       models.TransactionType      `json:"txnType" binding:"required"`
	Direction     models.TransactionDirection `json:"direction,omitempty"`
	Amount        float64                     `json:"amount" binding:"required,gt=0"`
	DueDate       *time.Time                  `json:"dueDate,omitempty"`
	Description   string                      `json:"description,omitempty"`
	DescriptionMr string                      `json:"descriptionMr,omitempty"`
}

func (h *TransactionHandler) Create(c *gin.Context) {
	var req createTxnReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	t := &models.FinancialTransaction{
		TxnType: req.TxnType, Direction: req.Direction, Amount: req.Amount,
		Currency: "INR", DueDate: req.DueDate,
		Description: req.Description, DescriptionMr: req.DescriptionMr,
	}
	if actor.IsAdmin() {
		t.MemberID = req.MemberID
		t.FlatID = req.FlatID
	}
	if err := h.repo.Create(actor, t); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, t)
}

func (h *TransactionHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	var from, to *time.Time
	if s := c.Query("from"); s != "" {
		if ts, err := time.Parse(time.RFC3339, s); err == nil {
			from = &ts
		}
	}
	if s := c.Query("to"); s != "" {
		if ts, err := time.Parse(time.RFC3339, s); err == nil {
			to = &ts
		}
	}
	rows, err := h.repo.ListForActor(actor, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"transactions": rows, "count": len(rows)})
}

func (h *TransactionHandler) GetByID(c *gin.Context) {
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

type markPaidReq struct {
	PaymentMethod models.PaymentMethod `json:"paymentMethod" binding:"required"`
	TransactionRef string              `json:"transactionRef,omitempty"`
}

func (h *TransactionHandler) MarkPaid(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req markPaidReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.MarkPaid(actor, id, req.PaymentMethod, req.TransactionRef); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Marked paid"})
}

func (h *TransactionHandler) Summary(c *gin.Context) {
	actor := middleware.GetActor(c)
	from := time.Now().AddDate(0, -1, 0)
	to := time.Now()
	if s := c.Query("from"); s != "" {
		if ts, err := time.Parse(time.RFC3339, s); err == nil {
			from = ts
		}
	}
	if s := c.Query("to"); s != "" {
		if ts, err := time.Parse(time.RFC3339, s); err == nil {
			to = ts
		}
	}
	credit, debit, err := h.repo.Summary(actor, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "SUMMARY_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"credit": credit, "debit": debit, "net": credit - debit,
		"from": from, "to": to,
	})
}
