package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/middleware"
	"sainath-society/internal/repositories"
)

type DefaulterHandler struct {
	repo *repositories.DefaulterRepository
}

func NewDefaulterHandler(repo *repositories.DefaulterRepository) *DefaulterHandler {
	return &DefaulterHandler{repo: repo}
}

// Register returns the full defaulter register with aging buckets.
func (h *DefaulterHandler) Register(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.GetDefaulterRegister(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"defaulters": rows, "count": len(rows)})
}

// Summary returns aggregated defaulter statistics.
func (h *DefaulterHandler) Summary(c *gin.Context) {
	actor := middleware.GetActor(c)
	summary, err := h.repo.GetDefaulterSummary(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, summary)
}

// MyStatement returns the current user's own statement.
func (h *DefaulterHandler) MyStatement(c *gin.Context) {
	actor := middleware.GetActor(c)
	rows, err := h.repo.GetMemberStatement(actor, actor.MemberID)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	var totalDebit, totalCredit float64
	for _, r := range rows {
		totalDebit += r.Debit
		totalCredit += r.Credit
	}
	c.JSON(http.StatusOK, gin.H{
		"statement":   rows,
		"count":       len(rows),
		"totalDebit":  totalDebit,
		"totalCredit": totalCredit,
		"balance":     totalDebit - totalCredit,
	})
}

// MemberStatement returns a chronological statement of account for a member.
func (h *DefaulterHandler) MemberStatement(c *gin.Context) {
	memberID, err := uuid.Parse(c.Param("memberId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid member id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	rows, err := h.repo.GetMemberStatement(actor, memberID)
	if err != nil {
		writeRepoError(c, err)
		return
	}

	// Calculate summary
	var totalDebit, totalCredit float64
	for _, r := range rows {
		totalDebit += r.Debit
		totalCredit += r.Credit
	}

	c.JSON(http.StatusOK, gin.H{
		"statement":   rows,
		"count":       len(rows),
		"totalDebit":  totalDebit,
		"totalCredit": totalCredit,
		"balance":     totalDebit - totalCredit,
	})
}
