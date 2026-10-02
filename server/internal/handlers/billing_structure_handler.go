package handlers

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type BillingStructureHandler struct {
	repo *repositories.BillingStructureRepository
}

func NewBillingStructureHandler(repo *repositories.BillingStructureRepository) *BillingStructureHandler {
	return &BillingStructureHandler{repo: repo}
}

// ─── Billing Structure ──────────────────────────────────────────

func (h *BillingStructureHandler) GetActive(c *gin.Context) {
	bs, err := h.repo.GetActive()
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, bs)
}

func (h *BillingStructureHandler) List(c *gin.Context) {
	rows, err := h.repo.ListAll()
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "LIST_FAILED"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"billingStructures": rows, "count": len(rows)})
}

type createBillingStructureReq struct {
	Name         string  `json:"name" binding:"required"`
	NameMr       string  `json:"nameMr"`
	InterestRate float64 `json:"interestRate"`
	IsActive     bool    `json:"isActive"`
}

func (h *BillingStructureHandler) Create(c *gin.Context) {
	var req createBillingStructureReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	bs := &models.BillingStructure{
		Name:         req.Name,
		NameMr:       req.NameMr,
		InterestRate: req.InterestRate,
		IsActive:     req.IsActive,
	}
	if err := h.repo.Create(actor, bs); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, bs)
}

type updateBillingStructureReq struct {
	Name         *string  `json:"name"`
	NameMr       *string  `json:"nameMr"`
	InterestRate *float64 `json:"interestRate"`
	IsActive     *bool    `json:"isActive"`
}

func (h *BillingStructureHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req updateBillingStructureReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	updates := map[string]interface{}{}
	if req.Name != nil {
		updates["name"] = *req.Name
	}
	if req.NameMr != nil {
		updates["name_mr"] = *req.NameMr
	}
	if req.InterestRate != nil {
		updates["interest_rate"] = *req.InterestRate
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Update(actor, id, updates); err != nil {
		writeRepoError(c, err)
		return
	}
	bs, _ := h.repo.GetByID(id)
	c.JSON(http.StatusOK, bs)
}

// ─── Charge Heads ───────────────────────────────────────────────

type addChargeHeadReq struct {
	Name       string             `json:"name" binding:"required"`
	NameMr     string             `json:"nameMr"`
	CalcMethod models.CalcMethod  `json:"calcMethod" binding:"required"`
	Rate       float64            `json:"rate" binding:"required,gt=0"`
	SortOrder  int                `json:"sortOrder"`
}

func (h *BillingStructureHandler) AddChargeHead(c *gin.Context) {
	bsID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req addChargeHeadReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	ch := &models.ChargeHead{
		BillingStructureID: bsID,
		Name:               req.Name,
		NameMr:             req.NameMr,
		CalcMethod:         req.CalcMethod,
		Rate:               req.Rate,
		SortOrder:          req.SortOrder,
		IsActive:           true,
	}
	if err := h.repo.AddChargeHead(actor, ch); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, ch)
}

type updateChargeHeadReq struct {
	Name       *string             `json:"name"`
	NameMr     *string             `json:"nameMr"`
	CalcMethod *models.CalcMethod  `json:"calcMethod"`
	Rate       *float64            `json:"rate"`
	SortOrder  *int                `json:"sortOrder"`
	IsActive   *bool               `json:"isActive"`
}

func (h *BillingStructureHandler) UpdateChargeHead(c *gin.Context) {
	id, err := uuid.Parse(c.Param("chId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req updateChargeHeadReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	updates := map[string]interface{}{}
	if req.Name != nil {
		updates["name"] = *req.Name
	}
	if req.NameMr != nil {
		updates["name_mr"] = *req.NameMr
	}
	if req.CalcMethod != nil {
		updates["calc_method"] = *req.CalcMethod
	}
	if req.Rate != nil {
		updates["rate"] = *req.Rate
	}
	if req.SortOrder != nil {
		updates["sort_order"] = *req.SortOrder
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}
	actor := middleware.GetActor(c)
	if err := h.repo.UpdateChargeHead(actor, id, updates); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Charge head updated"})
}

func (h *BillingStructureHandler) DeleteChargeHead(c *gin.Context) {
	id, err := uuid.Parse(c.Param("chId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.DeleteChargeHead(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Charge head removed"})
}

// ─── Bill Preview ───────────────────────────────────────────────

// Preview calculates what a bill would look like for a sample flat
// without actually creating anything. Useful for admin to verify rates.
func (h *BillingStructureHandler) Preview(c *gin.Context) {
	bs, err := h.repo.GetActive()
	if err != nil {
		writeRepoError(c, err)
		return
	}

	areaSqft := 1200.0 // default sample flat
	if s := c.Query("areaSqft"); s != "" {
		if _, err := fmt.Sscanf(s, "%f", &areaSqft); err != nil {
			areaSqft = 1200
		}
	}

	type linePreview struct {
		Name       string             `json:"name"`
		NameMr     string             `json:"nameMr"`
		CalcMethod models.CalcMethod  `json:"calcMethod"`
		Rate       float64            `json:"rate"`
		Quantity   float64            `json:"quantity"`
		Amount     float64            `json:"amount"`
	}

	var lines []linePreview
	var total float64
	for _, ch := range bs.ChargeHeads {
		var amount, qty float64
		switch ch.CalcMethod {
		case models.CalcPerSqft:
			amount = ch.Rate * areaSqft
			qty = areaSqft
		case models.CalcFixed:
			amount = ch.Rate
			qty = 1
		}
		total += amount
		lines = append(lines, linePreview{
			Name: ch.Name, NameMr: ch.NameMr,
			CalcMethod: ch.CalcMethod, Rate: ch.Rate,
			Quantity: qty, Amount: amount,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"billingStructure": bs.Name,
		"areaSqft":         areaSqft,
		"lineItems":        lines,
		"total":            total,
		"interestRate":     bs.InterestRate,
	})
}
