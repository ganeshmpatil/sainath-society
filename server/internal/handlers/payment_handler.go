package handlers

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type PaymentHandler struct {
	paymentRepo *repositories.PaymentRepository
	billRepo    *repositories.BillRepository
	rzpKeyID    string
	rzpSecret   string
}

func NewPaymentHandler(paymentRepo *repositories.PaymentRepository, billRepo *repositories.BillRepository, rzpKeyID, rzpSecret string) *PaymentHandler {
	return &PaymentHandler{
		paymentRepo: paymentRepo,
		billRepo:    billRepo,
		rzpKeyID:    rzpKeyID,
		rzpSecret:   rzpSecret,
	}
}

func (h *PaymentHandler) Enabled() bool {
	return h.rzpKeyID != "" && h.rzpSecret != ""
}

// ─── Razorpay config for mobile ──────────────────────────────────

func (h *PaymentHandler) GetConfig(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"keyId":   h.rzpKeyID,
		"enabled": h.rzpKeyID != "" && h.rzpSecret != "",
	})
}

// ─── Society bank details ────────────────────────────────────────

func (h *PaymentHandler) GetBankDetails(c *gin.Context) {
	cfg, err := h.paymentRepo.GetBankConfig()
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"bankConfig": nil})
		return
	}
	c.JSON(http.StatusOK, gin.H{"bankConfig": cfg})
}

// ─── Create Razorpay Order ───────────────────────────────────────

type createOrderReq struct {
	BillID string `json:"billId" binding:"required"`
}

func (h *PaymentHandler) CreateOrder(c *gin.Context) {
	if h.rzpKeyID == "" || h.rzpSecret == "" {
		c.JSON(http.StatusServiceUnavailable, response.ErrorResponse{Error: "Payment gateway not configured", Code: "PG_NOT_CONFIGURED"})
		return
	}

	var req createOrderReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}

	billID, err := uuid.Parse(req.BillID)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid bill ID", Code: "INVALID_ID"})
		return
	}

	actor := middleware.GetActor(c)

	// Fetch bill and verify ownership
	bill, err := h.billRepo.GetByID(actor, billID)
	if err != nil {
		writeRepoError(c, err)
		return
	}

	if bill.Status == models.BillPaid {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Bill already paid", Code: "ALREADY_PAID"})
		return
	}

	// Amount due in paise
	amountDue := bill.TotalAmount - bill.AmountPaid
	amountPaise := int64(amountDue * 100)

	// Create Razorpay order via API
	rzpOrder, err := h.createRazorpayOrder(amountPaise, bill.BillNo, bill.ID.String())
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to create payment order", Code: "RZP_ORDER_FAILED"})
		return
	}

	rzpOrderID, _ := rzpOrder["id"].(string)

	// Save payment order in our DB
	po := &models.PaymentOrder{
		BillID:          billID,
		MemberID:        actor.MemberID,
		RazorpayOrderID: rzpOrderID,
		Amount:          amountPaise,
		Currency:        "INR",
		Status:          models.PaymentCreated,
	}
	if err := h.paymentRepo.CreateOrder(po); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to save order", Code: "DB_ERROR"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"orderId":         po.ID,
		"razorpayOrderId": rzpOrderID,
		"razorpayKeyId":   h.rzpKeyID,
		"amount":          amountPaise,
		"currency":        "INR",
		"billNo":          bill.BillNo,
		"description":     fmt.Sprintf("Maintenance Bill %s", bill.BillNo),
	})
}

// ─── Verify Payment ──────────────────────────────────────────────

type verifyPaymentReq struct {
	RazorpayOrderID   string `json:"razorpayOrderId" binding:"required"`
	RazorpayPaymentID string `json:"razorpayPaymentId" binding:"required"`
	RazorpaySignature string `json:"razorpaySignature" binding:"required"`
}

func (h *PaymentHandler) VerifyPayment(c *gin.Context) {
	var req verifyPaymentReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}

	// Verify signature: HMAC-SHA256(razorpay_order_id + "|" + razorpay_payment_id, secret)
	payload := req.RazorpayOrderID + "|" + req.RazorpayPaymentID
	mac := hmac.New(sha256.New, []byte(h.rzpSecret))
	mac.Write([]byte(payload))
	expectedSig := hex.EncodeToString(mac.Sum(nil))

	if !hmac.Equal([]byte(expectedSig), []byte(req.RazorpaySignature)) {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid payment signature", Code: "INVALID_SIGNATURE"})
		return
	}

	// Update payment order
	po, err := h.paymentRepo.GetByRazorpayOrderID(req.RazorpayOrderID)
	if err != nil {
		c.JSON(http.StatusNotFound, response.ErrorResponse{Error: "Order not found", Code: "NOT_FOUND"})
		return
	}

	now := time.Now()
	po.RazorpayPaymentID = req.RazorpayPaymentID
	po.RazorpaySignature = req.RazorpaySignature
	po.Status = models.PaymentPaid
	po.PaidAt = &now

	if err := h.paymentRepo.UpdateOrder(po); err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to update order", Code: "DB_ERROR"})
		return
	}

	// Mark bill as paid (uses payment-verified method, no admin check needed)
	amountRupees := float64(po.Amount) / 100
	h.paymentRepo.MarkBillPaidByPayment(po.BillID, amountRupees, po.ID)

	c.JSON(http.StatusOK, gin.H{
		"message":   "Payment verified successfully",
		"paymentId": po.RazorpayPaymentID,
		"amount":    amountRupees,
		"billId":    po.BillID,
	})
}

// ─── Payment History ─────────────────────────────────────────────

func (h *PaymentHandler) ListPayments(c *gin.Context) {
	actor := middleware.GetActor(c)
	payments, err := h.paymentRepo.ListForMember(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: "Failed to list payments", Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"payments": payments, "count": len(payments)})
}

// ─── Razorpay API call ──────────────────────────────────────────

func (h *PaymentHandler) createRazorpayOrder(amountPaise int64, receipt, notes string) (map[string]interface{}, error) {
	body := fmt.Sprintf(`{"amount":%d,"currency":"INR","receipt":"%s","notes":{"billId":"%s"}}`, amountPaise, receipt, notes)
	req, err := http.NewRequest("POST", "https://api.razorpay.com/v1/orders", nil)
	if err != nil {
		return nil, fmt.Errorf("create request failed: %w", err)
	}
	req.SetBasicAuth(h.rzpKeyID, h.rzpSecret)
	req.Header.Set("Content-Type", "application/json")
	req.Body = io.NopCloser(
		// Use a simple string reader
		newStringReader(body),
	)
	req.ContentLength = int64(len(body))

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("razorpay error: %v", result)
	}
	return result, nil
}

type stringReader struct {
	s string
	i int
}

func newStringReader(s string) *stringReader { return &stringReader{s: s} }
func (r *stringReader) Read(p []byte) (int, error) {
	if r.i >= len(r.s) {
		return 0, io.EOF
	}
	n := copy(p, r.s[r.i:])
	r.i += n
	return n, nil
}
