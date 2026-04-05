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

type OwnershipHandler struct {
	repo *repositories.OwnershipRepository
}

func NewOwnershipHandler(repo *repositories.OwnershipRepository) *OwnershipHandler {
	return &OwnershipHandler{repo: repo}
}

type createOwnershipReq struct {
	MemberID       uuid.UUID             `json:"memberId" binding:"required"`
	FlatID         uuid.UUID             `json:"flatId" binding:"required"`
	OwnershipType  models.OwnershipType  `json:"ownershipType,omitempty"`
	SharePercent   float64               `json:"sharePercent,omitempty"`
	ShareCertNo    string                `json:"shareCertNo,omitempty"`
	SaleDeedNo     string                `json:"saleDeedNo,omitempty"`
	RegisteredDate *time.Time            `json:"registeredDate,omitempty"`
	PossessionDate *time.Time            `json:"possessionDate,omitempty"`
	PANNumber      string                `json:"panNumber,omitempty"`
	AadhaarLast4   string                `json:"aadhaarLast4,omitempty"`
}

func (h *OwnershipHandler) Create(c *gin.Context) {
	var req createOwnershipReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	o := &models.MemberOwnership{
		MemberID: req.MemberID, FlatID: req.FlatID,
		OwnershipType: req.OwnershipType, SharePercent: req.SharePercent,
		ShareCertNo: req.ShareCertNo, SaleDeedNo: req.SaleDeedNo,
		RegisteredDate: req.RegisteredDate, PossessionDate: req.PossessionDate,
		PANNumber: req.PANNumber, AadhaarLast4: req.AadhaarLast4,
		IsActive: true,
	}
	if o.OwnershipType == "" {
		o.OwnershipType = models.OwnershipTypeOwner
	}
	if o.SharePercent == 0 {
		o.SharePercent = 100
	}
	if err := h.repo.Create(actor, o); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, o)
}

func (h *OwnershipHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListForActor(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ownerships": rows, "count": len(rows)})
}

func (h *OwnershipHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	o, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, o)
}

type addHousingDocReq struct {
	DocType    models.DocumentType `json:"docType" binding:"required"`
	Title      string              `json:"title" binding:"required"`
	TitleMr    string              `json:"titleMr,omitempty"`
	FileURL    string              `json:"fileUrl" binding:"required"`
	FileSize   int64               `json:"fileSize,omitempty"`
	MimeType   string              `json:"mimeType,omitempty"`
	IssuedDate *time.Time          `json:"issuedDate,omitempty"`
	ExpiryDate *time.Time          `json:"expiryDate,omitempty"`
}

func (h *OwnershipHandler) AddDocument(c *gin.Context) {
	ownershipID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req addHousingDocReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	doc := &models.HousingDocument{
		DocType: req.DocType, Title: req.Title, TitleMr: req.TitleMr,
		FileURL: req.FileURL, FileSize: req.FileSize, MimeType: req.MimeType,
		IssuedDate: req.IssuedDate, ExpiryDate: req.ExpiryDate,
	}
	if err := h.repo.AddDocument(actor, ownershipID, doc); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, doc)
}

func (h *OwnershipHandler) ListDocuments(c *gin.Context) {
	ownershipID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListDocuments(actor, ownershipID)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"documents": rows, "count": len(rows)})
}
