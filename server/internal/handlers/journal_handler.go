package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/models"
	"aangan/internal/repositories"
)

type JournalHandler struct {
	repo       *repositories.JournalRepository
	accountRepo *repositories.AccountHeadRepository
}

func NewJournalHandler(repo *repositories.JournalRepository, accountRepo *repositories.AccountHeadRepository) *JournalHandler {
	return &JournalHandler{repo: repo, accountRepo: accountRepo}
}

// List returns journal entries with optional date range filter.
func (h *JournalHandler) List(c *gin.Context) {
	actor := middleware.GetActor(c)
	var from, to *time.Time
	if f := c.Query("from"); f != "" {
		if t, err := time.Parse("2006-01-02", f); err == nil {
			from = &t
		}
	}
	if t := c.Query("to"); t != "" {
		if parsed, err := time.Parse("2006-01-02", t); err == nil {
			to = &parsed
		}
	}
	rows, err := h.repo.List(actor, from, to)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"entries": rows, "count": len(rows)})
}

// GetByID returns a single journal entry with lines.
func (h *JournalHandler) GetByID(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid id", Code: "INVALID_ID"})
		return
	}
	je, err := h.repo.GetByID(id)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, je)
}

type createJournalReq struct {
	EntryDate   string             `json:"entryDate" binding:"required"` // YYYY-MM-DD
	Narration   string             `json:"narration" binding:"required"`
	NarrationMr string             `json:"narrationMr"`
	Lines       []journalLineReq   `json:"lines" binding:"required,min=2"`
}

type journalLineReq struct {
	AccountHeadID uuid.UUID `json:"accountHeadId" binding:"required"`
	DebitAmount   float64   `json:"debitAmount"`
	CreditAmount  float64   `json:"creditAmount"`
	Narration     string    `json:"narration"`
}

// Create inserts a manual journal entry.
func (h *JournalHandler) Create(c *gin.Context) {
	var req createJournalReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "INVALID_REQUEST"})
		return
	}
	entryDate, err := time.Parse("2006-01-02", req.EntryDate)
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid date format, use YYYY-MM-DD", Code: "INVALID_DATE"})
		return
	}

	var lines []models.JournalLine
	for _, l := range req.Lines {
		lines = append(lines, models.JournalLine{
			AccountHeadID: l.AccountHeadID,
			DebitAmount:   l.DebitAmount,
			CreditAmount:  l.CreditAmount,
			Narration:     l.Narration,
		})
	}

	je := &models.JournalEntry{
		EntryDate:   entryDate,
		Narration:   req.Narration,
		NarrationMr: req.NarrationMr,
		RefType:     "MANUAL",
		Lines:       lines,
	}

	actor := middleware.GetActor(c)
	if err := h.repo.Create(actor, je); err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: err.Error(), Code: "CREATE_FAILED"})
		return
	}

	// Reload with account head names
	full, _ := h.repo.GetByID(je.ID)
	c.JSON(http.StatusCreated, full)
}

// Ledger returns the ledger view for a specific account.
func (h *JournalHandler) Ledger(c *gin.Context) {
	accountID, err := uuid.Parse(c.Param("accountId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid account id", Code: "INVALID_ID"})
		return
	}
	actor := middleware.GetActor(c)
	var from, to *time.Time
	if f := c.Query("from"); f != "" {
		if t, err := time.Parse("2006-01-02", f); err == nil {
			from = &t
		}
	}
	if t := c.Query("to"); t != "" {
		if parsed, err := time.Parse("2006-01-02", t); err == nil {
			to = &parsed
		}
	}
	entries, err := h.repo.GetLedger(actor, accountID, from, to)
	if err != nil {
		writeRepoError(c, err)
		return
	}

	// Also return the account details
	account, _ := h.accountRepo.GetByID(accountID)

	c.JSON(http.StatusOK, gin.H{"account": account, "ledger": entries, "count": len(entries)})
}

// TrialBalance returns debit/credit totals for all accounts.
func (h *JournalHandler) TrialBalance(c *gin.Context) {
	actor := middleware.GetActor(c)
	var from, to *time.Time
	if f := c.Query("from"); f != "" {
		if t, err := time.Parse("2006-01-02", f); err == nil {
			from = &t
		}
	}
	if t := c.Query("to"); t != "" {
		if parsed, err := time.Parse("2006-01-02", t); err == nil {
			to = &parsed
		}
	}
	rows, err := h.repo.TrialBalance(actor, from, to)
	if err != nil {
		writeRepoError(c, err)
		return
	}

	var totalDebit, totalCredit float64
	for _, r := range rows {
		totalDebit += r.TotalDebit
		totalCredit += r.TotalCredit
	}

	c.JSON(http.StatusOK, gin.H{
		"rows":        rows,
		"count":       len(rows),
		"totalDebit":  totalDebit,
		"totalCredit": totalCredit,
		"balanced":    totalDebit == totalCredit,
	})
}
