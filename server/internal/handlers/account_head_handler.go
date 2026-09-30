package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

type AccountHeadHandler struct {
	repo *repositories.AccountHeadRepository
}

func NewAccountHeadHandler(repo *repositories.AccountHeadRepository) *AccountHeadHandler {
	return &AccountHeadHandler{repo: repo}
}

// ListTree returns the chart of accounts as a hierarchical tree.
func (h *AccountHeadHandler) ListTree(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListTree(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"accounts": rows, "count": len(rows)})
}

// ListAll returns a flat list of all active accounts.
func (h *AccountHeadHandler) ListAll(c *gin.Context) {
	actor := middleware.GetActor(c)

	// Optional type filter
	if t := c.Query("type"); t != "" {
		rows, err := h.repo.ListByType(actor, models.AccountType(t))
		if err != nil {
			writeRepoError(c, err)
			return
		}
		c.JSON(http.StatusOK, gin.H{"accounts": rows, "count": len(rows)})
		return
	}

	rows, err := h.repo.ListAll(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"accounts": rows, "count": len(rows)})
}

// ListLeaf returns only leaf (non-group) accounts for journal entry dropdowns.
func (h *AccountHeadHandler) ListLeaf(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.ListLeafAccounts(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"accounts": rows, "count": len(rows)})
}

// GetByID returns a single account with its children.
func (h *AccountHeadHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	ah, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, ah)
}

type createAccountHeadReq struct {
	Code     string             `json:"code" binding:"required"`
	Name     string             `json:"name" binding:"required"`
	NameMr   string             `json:"nameMr"`
	Type     models.AccountType `json:"type" binding:"required"`
	ParentID *uuid.UUID         `json:"parentId"`
	IsGroup  bool               `json:"isGroup"`
}

// Create adds a new account head to the chart.
func (h *AccountHeadHandler) Create(c *gin.Context) {
	var req createAccountHeadReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	actor := middleware.GetActor(c)
	ah := &models.AccountHead{
		Code:     req.Code,
		Name:     req.Name,
		NameMr:   req.NameMr,
		Type:     req.Type,
		ParentID: req.ParentID,
		IsGroup:  req.IsGroup,
		IsActive: true,
	}
	if err := h.repo.Create(actor, ah); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusCreated, ah)
}

type updateAccountHeadReq struct {
	Name     *string `json:"name"`
	NameMr   *string `json:"nameMr"`
	Code     *string `json:"code"`
	IsActive *bool   `json:"isActive"`
	IsGroup  *bool   `json:"isGroup"`
}

// Update modifies an existing account head.
func (h *AccountHeadHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	var req updateAccountHeadReq
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
	if req.Code != nil {
		updates["code"] = *req.Code
	}
	if req.IsActive != nil {
		updates["is_active"] = *req.IsActive
	}
	if req.IsGroup != nil {
		updates["is_group"] = *req.IsGroup
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Update(actor, id, updates); err != nil {
		writeRepoError(c, err)
		return
	}
	ah, _ := h.repo.GetByID(id)
	c.JSON(http.StatusOK, ah)
}

// Delete soft-deletes an account head (non-system only).
func (h *AccountHeadHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	if err := h.repo.Delete(actor, id); err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Account head deleted"})
}
