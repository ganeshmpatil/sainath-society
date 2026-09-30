package handlers

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
	"sainath-society/internal/services"
)

type BillHandler struct {
	repo     *repositories.BillRepository
	notifier *services.Notifier
}

func NewBillHandler(repo *repositories.BillRepository, notifier *services.Notifier) *BillHandler {
	return &BillHandler{repo: repo, notifier: notifier}
}

type generateBillsReq struct {
	BillingPeriod     string    `json:"billingPeriod" binding:"required"` // e.g. "2026-04"
	DueDate           time.Time `json:"dueDate" binding:"required"`
	MaintenanceCharge float64   `json:"maintenanceCharge"` // optional when billing structure is active
	SinkingFund       float64   `json:"sinkingFund"`
	RepairFund        float64   `json:"repairFund"`
	WaterCharge       float64   `json:"waterCharge"`
	OtherCharges      float64   `json:"otherCharges"`
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

	// Notify each member about their generated bill
	if created > 0 {
		go func() {
			bills, err := h.repo.ListByPeriod(req.BillingPeriod)
			if err != nil {
				return
			}
			dueStr := req.DueDate.Format("02 Jan 2006")
			for _, b := range bills {
				h.notifier.BillGenerated(b.MemberID, b.BillNo, b.TotalAmount, dueStr, b.ID)
			}
		}()
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

	// Fetch bill before to get member + bill number
	bill, _ := h.repo.GetByID(actor, id)

	if err := h.repo.MarkPaid(actor, id, req.Amount, req.TxnID); err != nil {
		writeRepoError(c, err)
		return
	}

	// Notify member about payment received
	if bill != nil {
		go h.notifier.BillPaid(bill.MemberID, bill.BillNo, req.Amount, id)
	}

	c.JSON(http.StatusOK, gin.H{"message": "Marked paid"})
}

// ─── Multi-Mode Payment Recording (FIN-008 + FIN-010) ─────────────

type recordPaymentReq struct {
	Amount      float64 `json:"amount" binding:"required,gt=0"`
	PaymentMode string  `json:"paymentMode" binding:"required"` // RAZORPAY, UPI, NEFT, CHEQUE, CASH
	PaymentDate string  `json:"paymentDate" binding:"required"` // 2026-09-30
	Reference   string  `json:"reference"`                      // UTR, cheque no, etc.
	ChequeBank  string  `json:"chequeBank"`
	ChequeDate  string  `json:"chequeDate"`
}

func (h *BillHandler) RecordPayment(c *gin.Context) {
	billID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req recordPaymentReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)

	payDate, err := time.Parse("2006-01-02", req.PaymentDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid payment date", Code: "INVALID_DATE"})
		return
	}

	payment := &models.BillPayment{
		BillID:      billID,
		Amount:      req.Amount,
		PaymentMode: models.PaymentMode(req.PaymentMode),
		PaymentDate: payDate,
		Reference:   req.Reference,
		ChequeBank:  req.ChequeBank,
	}

	if req.ChequeDate != "" {
		if cd, err := time.Parse("2006-01-02", req.ChequeDate); err == nil {
			payment.ChequeDate = &cd
			payment.ChequeStatus = models.ChequeReceived
		}
	}

	// Fetch bill before to get member + bill number for notification
	bill, _ := h.repo.GetByID(actor, billID)

	if err := h.repo.RecordPayment(actor, payment); err != nil {
		writeRepoError(c, err)
		return
	}

	// Notify member
	if bill != nil {
		go h.notifier.BillPaid(bill.MemberID, bill.BillNo, req.Amount, billID)
	}

	c.JSON(http.StatusCreated, payment)
}

func (h *BillHandler) ListPayments(c *gin.Context) {
	billID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListPaymentsForBill(actor, billID)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"payments": rows})
}

// ─── Payment Reminders (FIN-020) ──────────────────────────────────

func (h *BillHandler) SendReminders(c *gin.Context) {
	actor := middleware.GetActor(c)
	if !actor.IsAdmin() {
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: "Admin only", Code: "FORBIDDEN"})
		return
	}

	sent := 0

	// Stage 1: Bills due in 3 days
	dueSoon, _ := h.repo.GetBillsDueSoon(3)
	for _, b := range dueSoon {
		due := b.TotalAmount - b.AmountPaid
		dueDate := b.DueDate.Format("02 Jan 2006")
		h.notifier.NotifyOne(b.MemberID,
			"Payment Reminder: "+b.BillNo,
			fmt.Sprintf("Reminder: Bill #%s for Rs. %.0f is due on %s. Please pay before the due date to avoid interest.", b.BillNo, due, dueDate),
			fmt.Sprintf("स्मरणपत्र: बिल #%s रु. %.0f %s पर्यंत देय आहे. व्याज टाळण्यासाठी कृपया वेळेवर भरा.", b.BillNo, due, dueDate),
			"PAYMENT_REMINDER", "bill", &b.ID,
		)
		sent++
	}

	// Stage 2: Overdue bills
	overdue, _ := h.repo.GetOverdueBills()
	for _, b := range overdue {
		due := b.TotalAmount - b.AmountPaid
		daysOverdue := int(time.Since(b.DueDate).Hours() / 24)

		var severity string
		if daysOverdue > 90 {
			severity = "FINAL_NOTICE"
		} else if daysOverdue > 30 {
			severity = "ESCALATED"
		} else if daysOverdue > 15 {
			severity = "WARNING"
		} else {
			severity = "OVERDUE"
		}

		h.notifier.NotifyOne(b.MemberID,
			fmt.Sprintf("Overdue: %s (%d days)", b.BillNo, daysOverdue),
			fmt.Sprintf("Bill #%s is overdue by %d days. Outstanding: Rs. %.0f. Please clear your dues immediately to avoid further action.", b.BillNo, daysOverdue, due),
			fmt.Sprintf("बिल #%s %d दिवसांनी थकीत आहे. थकबाकी: रु. %.0f. कृपया पुढील कारवाई टाळण्यासाठी तातडीने भरणा करा.", b.BillNo, daysOverdue, due),
			severity, "bill", &b.ID,
		)
		sent++
	}

	c.JSON(http.StatusOK, gin.H{"remindersSent": sent, "dueSoon": len(dueSoon), "overdue": len(overdue)})
}

// ─── Overdue Summary ──────────────────────────────────────────────

func (h *BillHandler) OverdueSummary(c *gin.Context) {
	actor := middleware.GetActor(c)
	if !actor.IsAdmin() {
		c.JSON(http.StatusForbidden, response.ErrorResponse{Error: "Admin only", Code: "FORBIDDEN"})
		return
	}

	overdue, _ := h.repo.GetOverdueBills()
	dueSoon, _ := h.repo.GetBillsDueSoon(3)

	totalOverdue := 0.0
	for _, b := range overdue {
		totalOverdue += b.TotalAmount - b.AmountPaid
	}

	c.JSON(http.StatusOK, gin.H{
		"overdueCount":    len(overdue),
		"totalOverdue":    totalOverdue,
		"dueSoonCount":    len(dueSoon),
	})
}
