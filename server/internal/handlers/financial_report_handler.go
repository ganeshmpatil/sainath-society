package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"aangan/internal/dto/response"
	"aangan/internal/middleware"
	"aangan/internal/repositories"
)

type FinancialReportHandler struct {
	repo *repositories.FinancialReportRepository
}

func NewFinancialReportHandler(repo *repositories.FinancialReportRepository) *FinancialReportHandler {
	return &FinancialReportHandler{repo: repo}
}

// IncomeExpenditure returns the I&E statement for a date range.
// Defaults to current financial year (April 1 to March 31).
func (h *FinancialReportHandler) IncomeExpenditure(c *gin.Context) {
	actor := middleware.GetActor(c)

	from, to := defaultFinancialYear()
	if f := c.Query("from"); f != "" {
		if t, err := time.Parse("2006-01-02", f); err == nil {
			from = t
		}
	}
	if t := c.Query("to"); t != "" {
		if parsed, err := time.Parse("2006-01-02", t); err == nil {
			to = parsed
		}
	}

	stmt, err := h.repo.GetIncomeExpenditure(actor, from, to)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, stmt)
}

// BalanceSheet returns the balance sheet as of a date (default: today).
func (h *FinancialReportHandler) BalanceSheet(c *gin.Context) {
	actor := middleware.GetActor(c)

	asOf := time.Now()
	if d := c.Query("asOf"); d != "" {
		if parsed, err := time.Parse("2006-01-02", d); err == nil {
			asOf = parsed
		}
	}

	bs, err := h.repo.GetBalanceSheet(actor, asOf)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, bs)
}

// ReceiptsPayments returns the cash-basis receipts & payments account.
func (h *FinancialReportHandler) ReceiptsPayments(c *gin.Context) {
	actor := middleware.GetActor(c)

	from, to, err := parseFinancialYearQuery(c)
	if err != nil {
		return
	}

	rp, err := h.repo.GetReceiptsPayments(actor, from, to)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, rp)
}

// CollectionDashboard returns collection efficiency metrics.
func (h *FinancialReportHandler) CollectionDashboard(c *gin.Context) {
	actor := middleware.GetActor(c)
	stats, err := h.repo.GetCollectionStats(actor)
	if err != nil {
		writeRepoError(c, err)
		return
	}
	c.JSON(http.StatusOK, stats)
}

// TrialBalance is forwarded from journal handler but included here for completeness.

// defaultFinancialYear returns April 1 to March 31 of the current financial year.
func defaultFinancialYear() (time.Time, time.Time) {
	now := time.Now()
	year := now.Year()
	if now.Month() < time.April {
		year--
	}
	from := time.Date(year, time.April, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(year+1, time.March, 31, 23, 59, 59, 0, time.UTC)
	return from, to
}

// ValidateFinancialYearParams is a helper to parse optional financial year params.
func parseFinancialYearQuery(c *gin.Context) (time.Time, time.Time, error) {
	from, to := defaultFinancialYear()
	if f := c.Query("from"); f != "" {
		t, err := time.Parse("2006-01-02", f)
		if err != nil {
			c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid from date", Code: "INVALID_DATE"})
			return from, to, err
		}
		from = t
	}
	if t := c.Query("to"); t != "" {
		parsed, err := time.Parse("2006-01-02", t)
		if err != nil {
			c.JSON(http.StatusBadRequest, response.ErrorResponse{Error: "Invalid to date", Code: "INVALID_DATE"})
			return from, to, err
		}
		to = parsed
	}
	return from, to, nil
}
