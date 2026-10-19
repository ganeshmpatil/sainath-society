package handlers

import (
	"net/http"

	"aangan/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type MarketingHandler struct {
	db *gorm.DB
}

func NewMarketingHandler(db *gorm.DB) *MarketingHandler {
	return &MarketingHandler{db: db}
}

type createDemoReq struct {
	ContactPerson string `json:"contact_person" binding:"required"`
	Phone         string `json:"phone" binding:"required"`
	Email         string `json:"email"`
	SocietyName   string `json:"society_name"`
	City          string `json:"city"`
	TotalFlats    string `json:"total_flats"`
	Role          string `json:"role"`
	Message       string `json:"message"`
}

func (h *MarketingHandler) CreateDemo(c *gin.Context) {
	var req createDemoReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	demo := models.DemoRequest{
		ContactPerson: req.ContactPerson,
		Phone:         req.Phone,
		Email:         req.Email,
		SocietyName:   req.SocietyName,
		City:          req.City,
		TotalFlats:    req.TotalFlats,
		Role:          req.Role,
		Message:       req.Message,
	}

	if err := h.db.Create(&demo).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save demo request"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"success": true, "id": demo.ID})
}

func (h *MarketingHandler) ListDemos(c *gin.Context) {
	var rows []models.DemoRequest
	if err := h.db.Order("created_at DESC").Find(&rows).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"demos": rows, "count": len(rows)})
}

type createInquiryReq struct {
	Name        string `json:"name" binding:"required"`
	Phone       string `json:"phone" binding:"required"`
	Email       string `json:"email"`
	SocietyName string `json:"society_name"`
	Message     string `json:"message"`
}

func (h *MarketingHandler) CreateInquiry(c *gin.Context) {
	var req createInquiryReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	inquiry := models.Inquiry{
		Name:        req.Name,
		Phone:       req.Phone,
		Email:       req.Email,
		SocietyName: req.SocietyName,
		Message:     req.Message,
	}

	if err := h.db.Create(&inquiry).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save inquiry"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"success": true, "id": inquiry.ID})
}

func (h *MarketingHandler) ListInquiries(c *gin.Context) {
	var rows []models.Inquiry
	if err := h.db.Order("created_at DESC").Find(&rows).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"inquiries": rows, "count": len(rows)})
}
