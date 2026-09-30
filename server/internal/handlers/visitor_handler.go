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
	"sainath-society/internal/services"
)

type VisitorHandler struct {
	repo     *repositories.VisitorRepository
	notifier *services.Notifier
}

func NewVisitorHandler(repo *repositories.VisitorRepository, notifier *services.Notifier) *VisitorHandler {
	return &VisitorHandler{repo: repo, notifier: notifier}
}

// ─── Visitor Entry Log ─────────────────────────────────────────

func (h *VisitorHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	var flatID *uuid.UUID
	if fid := c.Query("flatId"); fid != "" {
		if id, err := uuid.Parse(fid); err == nil {
			flatID = &id
		}
	}
	status := c.Query("status")
	var date *time.Time
	if d := c.Query("date"); d != "" {
		if t, err := time.Parse("2006-01-02", d); err == nil {
			date = &t
		}
	}
	visitors, err := h.repo.List(actor, flatID, status, date)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"visitors": visitors, "count": len(visitors)})
}

type createVisitorReq struct {
	Name        string             `json:"name" binding:"required,max=100"`
	Phone       string             `json:"phone,omitempty"`
	VisitorType models.VisitorType `json:"visitorType" binding:"required"`
	Purpose     string             `json:"purpose,omitempty"`
	FlatID      uuid.UUID          `json:"flatId" binding:"required"`
	FlatNo      string             `json:"flatNo" binding:"required"`
	VehicleNo   string             `json:"vehicleNo,omitempty"`
	CompanyName string             `json:"companyName,omitempty"`
	Notes       string             `json:"notes,omitempty"`
}

func (h *VisitorHandler) Create(c *gin.Context) {
	var req createVisitorReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	v := &models.Visitor{
		Name:        req.Name,
		Phone:       req.Phone,
		VisitorType: req.VisitorType,
		Purpose:     req.Purpose,
		FlatID:      req.FlatID,
		FlatNo:      req.FlatNo,
		VehicleNo:   req.VehicleNo,
		CompanyName: req.CompanyName,
		Notes:       req.Notes,
		Status:      models.VisitorPending,
	}
	if err := h.repo.Create(actor, v); err != nil {
		writeRepoError(c, err)
		return
	}

	// Notify flat resident about new visitor
	go h.notifier.NotifyFlatMembers(req.FlatID, "Visitor Arrived", "You have a visitor: "+req.Name, "तुमच्या फ्लॅटसाठी भेटकर्ता: "+req.Name, "VISITOR_ENTRY", "visitor", nil)

	c.JSON(http.StatusCreated, v)
}

func (h *VisitorHandler) Approve(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.Approve(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Approved and checked in"})
}

func (h *VisitorHandler) CheckOut(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	if err := h.repo.CheckOut(id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Checked out"})
}

func (h *VisitorHandler) Reject(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req struct {
		Reason string `json:"reason"`
	}
	_ = c.ShouldBindJSON(&req) // intentionally ignored: body is optional (Reason only)
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	if err := h.repo.Reject(actor, id, req.Reason); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Rejected"})
}

func (h *VisitorHandler) TodaySummary(c *gin.Context) {
	summary, err := h.repo.TodaySummary()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "SUMMARY_FAILED"})
		return
	}
	c.JSON(http.StatusOK, summary)
}

// ─── Frequent Visitors ─────────────────────────────────────────

func (h *VisitorHandler) ListFrequent(c *gin.Context) {
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	var flatID *uuid.UUID
	if fid := c.Query("flatId"); fid != "" {
		if id, err := uuid.Parse(fid); err == nil {
			flatID = &id
		}
	}
	fv, err := h.repo.ListFrequent(actor, flatID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"frequentVisitors": fv, "count": len(fv)})
}

type createFrequentVisitorReq struct {
	Name        string             `json:"name" binding:"required,max=100"`
	NameMr      string             `json:"nameMr,omitempty"`
	Phone       string             `json:"phone,omitempty"`
	VisitorType models.VisitorType `json:"visitorType"`
	FlatID      uuid.UUID          `json:"flatId" binding:"required"`
	FlatNo      string             `json:"flatNo" binding:"required"`
	Role        string             `json:"role,omitempty"`
	RoleMr      string             `json:"roleMr,omitempty"`
}

func (h *VisitorHandler) CreateFrequent(c *gin.Context) {
	var req createFrequentVisitorReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if actor == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	fv := &models.FrequentVisitor{
		Name:        req.Name,
		NameMr:      req.NameMr,
		Phone:       req.Phone,
		VisitorType: req.VisitorType,
		FlatID:      req.FlatID,
		FlatNo:      req.FlatNo,
		Role:        req.Role,
		RoleMr:      req.RoleMr,
		IsActive:    true,
	}
	if err := h.repo.CreateFrequent(actor, fv); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, fv)
}

func (h *VisitorHandler) DeleteFrequent(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	if err := h.repo.DeleteFrequent(id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Deleted"})
}

func (h *VisitorHandler) BlacklistFrequent(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req struct {
		Reason string `json:"reason"`
	}
	_ = c.ShouldBindJSON(&req) // intentionally ignored: body is optional (Reason only)
	if err := h.repo.BlacklistFrequent(id, req.Reason); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Blacklisted"})
}
