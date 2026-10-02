package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type CertificateHandler struct {
	repo *repositories.CertificateRepository
}

func NewCertificateHandler(repo *repositories.CertificateRepository) *CertificateHandler {
	return &CertificateHandler{repo: repo}
}

type requestCertReq struct {
	Type       string    `json:"type" binding:"required"`       // NO_DUES, NOC
	FlatID     uuid.UUID `json:"flatId" binding:"required"`
	Purpose    string    `json:"purpose"`
	BuyerName  string    `json:"buyerName"`
	SaleAmount float64   `json:"saleAmount"`
}

func (h *CertificateHandler) Request(c *gin.Context) {
	var req requestCertReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	cert := &models.Certificate{
		Type:       models.CertificateType(req.Type),
		FlatID:     req.FlatID,
		MemberID:   actor.MemberID,
		Purpose:    req.Purpose,
		BuyerName:  req.BuyerName,
		SaleAmount: req.SaleAmount,
	}
	if err := h.repo.Request(actor, cert); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, cert)
}

func (h *CertificateHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.List(actor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"certificates": rows, "count": len(rows)})
}

func (h *CertificateHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	cert, err := h.repo.GetByID(actor, id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, cert)
}

func (h *CertificateHandler) Approve(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Approve(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Certificate approved"})
}

type rejectCertReq struct {
	Reason string `json:"reason" binding:"required"`
}

func (h *CertificateHandler) Reject(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid ID", Code: "INVALID_ID"})
		return
	}
	var req rejectCertReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Reject(actor, id, req.Reason); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Certificate rejected"})
}

func (h *CertificateHandler) NoDuesCheck(c *gin.Context) {
	flatID, err := uuid.Parse(c.Param("flatId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid flat ID", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	data, err := h.repo.GetNoDuesData(actor, flatID)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, data)
}
