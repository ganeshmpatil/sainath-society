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

type StaffHandler struct {
	repo *repositories.StaffRepository
}

func NewStaffHandler(repo *repositories.StaffRepository) *StaffHandler {
	return &StaffHandler{repo: repo}
}

func (h *StaffHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	includeInactive := c.Query("includeInactive") == "true" && actor.IsAdmin()
	rows, err := h.repo.List(actor, includeInactive)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"staff": rows, "count": len(rows)})
}

func (h *StaffHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	s, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, s)
}

type createStaffReq struct {
	Name          string  `json:"name" binding:"required"`
	NameMr        string  `json:"nameMr"`
	Mobile        string  `json:"mobile" binding:"required"`
	AltMobile     string  `json:"altMobile"`
	Role          string  `json:"role" binding:"required"`
	StaffType     string  `json:"staffType"`
	AadhaarNo     string  `json:"aadhaarNo"`
	Address       string  `json:"address"`
	MonthlySalary float64 `json:"monthlySalary" binding:"required,gt=0"`
	JoiningDate   string  `json:"joiningDate" binding:"required"` // 2026-01-15
	ShiftStart    string  `json:"shiftStart"`
	ShiftEnd      string  `json:"shiftEnd"`
	BankAccount   string  `json:"bankAccount"`
	BankIFSC      string  `json:"bankIfsc"`
	Notes         string  `json:"notes"`
}

func (h *StaffHandler) Create(c *gin.Context) {
	var req createStaffReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	joinDate, err := time.Parse("2006-01-02", req.JoiningDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid joining date", Code: "INVALID_DATE"})
		return
	}
	staffType := models.StaffPermanent
	if req.StaffType == "CONTRACT" {
		staffType = models.StaffContract
	}
	actor := middleware.GetActor(c)
	s := &models.Staff{
		Name:          req.Name,
		NameMr:        req.NameMr,
		Mobile:        req.Mobile,
		AltMobile:     req.AltMobile,
		Role:          models.StaffRole(req.Role),
		StaffType:     staffType,
		AadhaarNo:     req.AadhaarNo,
		Address:       req.Address,
		MonthlySalary: req.MonthlySalary,
		JoiningDate:   joinDate,
		ShiftStart:    req.ShiftStart,
		ShiftEnd:      req.ShiftEnd,
		BankAccount:   req.BankAccount,
		BankIFSC:      req.BankIFSC,
		Notes:         req.Notes,
	}
	if err := h.repo.Create(actor, s); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, s)
}

func (h *StaffHandler) Update(c *gin.Context) {
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
	c.JSON(http.StatusOK, gin.H{"message": "Staff updated"})
}

// ─── Attendance ────────────────────────────────────────────────

type staffAttendanceReq struct {
	StaffID string `json:"staffId" binding:"required"`
	Date    string `json:"date" binding:"required"`
	Status  string `json:"status" binding:"required"` // PRESENT, ABSENT, HALF_DAY, LEAVE
	InTime  string `json:"inTime"`
	OutTime string `json:"outTime"`
	Notes   string `json:"notes"`
}

func (h *StaffHandler) MarkAttendance(c *gin.Context) {
	var req staffAttendanceReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	staffID, _ := uuid.Parse(req.StaffID)
	date, _ := time.Parse("2006-01-02", req.Date)
	actor := middleware.GetActor(c)
	att := &models.StaffAttendance{
		StaffID: staffID,
		Date:    date,
		Status:  req.Status,
		InTime:  req.InTime,
		OutTime: req.OutTime,
		Notes:   req.Notes,
	}
	if err := h.repo.MarkAttendance(actor, att); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Attendance marked"})
}

type bulkAttendanceReq struct {
	Date    string `json:"date" binding:"required"`
	Records []struct {
		StaffID string `json:"staffId"`
		Status  string `json:"status"`
		InTime  string `json:"inTime"`
		OutTime string `json:"outTime"`
	} `json:"records" binding:"required"`
}

func (h *StaffHandler) BulkAttendance(c *gin.Context) {
	var req bulkAttendanceReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	date, _ := time.Parse("2006-01-02", req.Date)
	actor := middleware.GetActor(c)
	var records []models.StaffAttendance
	for _, r := range req.Records {
		sid, _ := uuid.Parse(r.StaffID)
		records = append(records, models.StaffAttendance{
			StaffID: sid,
			Status:  r.Status,
			InTime:  r.InTime,
			OutTime: r.OutTime,
		})
	}
	marked, err := h.repo.BulkMarkAttendance(actor, date, records)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"marked": marked})
}

func (h *StaffHandler) GetAttendance(c *gin.Context) {
	staffID, _ := uuid.Parse(c.Param("id"))
	month := c.Query("month")
	if month == "" {
		month = time.Now().Format("2006-01")
	}
	rows, err := h.repo.GetAttendance(staffID, month)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "FETCH_FAILED"})
		return
	}
	present, absent, halfDay, leave, _ := h.repo.AttendanceSummary(staffID, month)
	c.JSON(http.StatusOK, gin.H{
		"attendance": rows,
		"summary":    gin.H{"present": present, "absent": absent, "halfDay": halfDay, "leave": leave},
	})
}

func (h *StaffHandler) TodayAttendance(c *gin.Context) {
	rows, err := h.repo.TodayAttendance()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "FETCH_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"attendance": rows})
}

// ─── Salary ────────────────────────────────────────────────────

func (h *StaffHandler) CalculateSalary(c *gin.Context) {
	staffID, _ := uuid.Parse(c.Param("id"))
	month := c.Query("month")
	if month == "" {
		month = time.Now().Format("2006-01")
	}
	payment, err := h.repo.CalculateSalary(staffID, month)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, payment)
}

type recordSalaryReq struct {
	StaffID     string  `json:"staffId" binding:"required"`
	Month       string  `json:"month" binding:"required"`
	WorkingDays int     `json:"workingDays"`
	PresentDays int     `json:"presentDays"`
	GrossAmount float64 `json:"grossAmount" binding:"required,gt=0"`
	Deductions  float64 `json:"deductions"`
	NetAmount   float64 `json:"netAmount" binding:"required,gt=0"`
	PaymentMode string  `json:"paymentMode"`
	Notes       string  `json:"notes"`
}

func (h *StaffHandler) RecordSalary(c *gin.Context) {
	var req recordSalaryReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	staffID, _ := uuid.Parse(req.StaffID)
	actor := middleware.GetActor(c)
	payment := &models.StaffSalaryPayment{
		StaffID:     staffID,
		Month:       req.Month,
		WorkingDays: req.WorkingDays,
		PresentDays: req.PresentDays,
		GrossAmount: req.GrossAmount,
		Deductions:  req.Deductions,
		NetAmount:   req.NetAmount,
		PaymentMode: req.PaymentMode,
		PaidDate:    time.Now(),
		Notes:       req.Notes,
	}
	if err := h.repo.RecordSalaryPayment(actor, payment); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, payment)
}

func (h *StaffHandler) ListSalaryPayments(c *gin.Context) {
	staffID, _ := uuid.Parse(c.Param("id"))
	rows, err := h.repo.ListSalaryPayments(staffID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "FETCH_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"payments": rows})
}

func (h *StaffHandler) MonthlySummary(c *gin.Context) {
	month := c.Query("month")
	if month == "" {
		month = time.Now().Format("2006-01")
	}
	gross, net, count, err := h.repo.MonthlySalarySummary(month)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "FETCH_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"month": month, "totalGross": gross, "totalNet": net, "staffPaid": count})
}
