package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"aangan/internal/dto/response"
)

type AnalyticsHandler struct {
	db *gorm.DB
}

func NewAnalyticsHandler(db *gorm.DB) *AnalyticsHandler {
	return &AnalyticsHandler{db: db}
}

// GET /analytics/collection-efficiency
// Monthly collection % (bills paid vs total) for last 12 months.
func (h *AnalyticsHandler) CollectionEfficiency(c *gin.Context) {
	type Row struct {
		Month      string  `json:"month"`
		Total      int64   `json:"total"`
		Paid       int64   `json:"paid"`
		Percentage float64 `json:"percentage"`
	}

	var rows []Row
	err := h.db.Raw(`
		SELECT
			TO_CHAR(DATE_TRUNC('month', issue_date), 'YYYY-MM') AS month,
			COUNT(*) AS total,
			COUNT(*) FILTER (WHERE status IN ('PAID')) AS paid,
			ROUND(
				100.0 * COUNT(*) FILTER (WHERE status IN ('PAID')) / NULLIF(COUNT(*), 0),
				1
			) AS percentage
		FROM soc_mitra_maintenance_bills
		WHERE issue_date >= NOW() - INTERVAL '12 months'
		GROUP BY DATE_TRUNC('month', issue_date)
		ORDER BY DATE_TRUNC('month', issue_date)
	`).Scan(&rows).Error
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "QUERY_FAILED"})
		return
	}
	if rows == nil {
		rows = []Row{}
	}
	c.JSON(http.StatusOK, gin.H{"data": rows})
}

// GET /analytics/grievance-trends
// Grievance counts by status and avg resolution days, by month for last 12 months.
func (h *AnalyticsHandler) GrievanceTrends(c *gin.Context) {
	type MonthRow struct {
		Month      string `json:"month"`
		Open       int64  `json:"open"`
		InProgress int64  `json:"inProgress"`
		Resolved   int64  `json:"resolved"`
	}
	type Summary struct {
		Open           int64   `json:"open"`
		InProgress     int64   `json:"inProgress"`
		Resolved       int64   `json:"resolved"`
		AvgResolutionDays float64 `json:"avgResolutionDays"`
	}

	var months []MonthRow
	err := h.db.Raw(`
		SELECT
			TO_CHAR(DATE_TRUNC('month', created_at), 'YYYY-MM') AS month,
			COUNT(*) FILTER (WHERE status = 'OPEN')        AS open,
			COUNT(*) FILTER (WHERE status = 'IN_PROGRESS') AS in_progress,
			COUNT(*) FILTER (WHERE status IN ('RESOLVED', 'CLOSED')) AS resolved
		FROM soc_mitra_grievances
		WHERE created_at >= NOW() - INTERVAL '12 months'
		GROUP BY DATE_TRUNC('month', created_at)
		ORDER BY DATE_TRUNC('month', created_at)
	`).Scan(&months).Error
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "QUERY_FAILED"})
		return
	}

	var summary Summary
	_ = h.db.Raw(`
		SELECT
			COUNT(*) FILTER (WHERE status = 'OPEN')        AS open,
			COUNT(*) FILTER (WHERE status = 'IN_PROGRESS') AS in_progress,
			COUNT(*) FILTER (WHERE status IN ('RESOLVED', 'CLOSED')) AS resolved,
			COALESCE(AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 86400.0) FILTER (WHERE resolved_at IS NOT NULL), 0) AS avg_resolution_days
		FROM soc_mitra_grievances
	`).Scan(&summary).Error

	if months == nil {
		months = []MonthRow{}
	}
	c.JSON(http.StatusOK, gin.H{"months": months, "summary": summary})
}

// GET /analytics/occupancy
// Count of owner-occupied, tenant-occupied, vacant flats.
func (h *AnalyticsHandler) Occupancy(c *gin.Context) {
	type Result struct {
		Total          int64 `json:"total"`
		OwnerOccupied  int64 `json:"ownerOccupied"`
		TenantOccupied int64 `json:"tenantOccupied"`
		Vacant         int64 `json:"vacant"`
	}

	var result Result
	err := h.db.Raw(`
		SELECT
			COUNT(*) AS total,
			COUNT(*) FILTER (WHERE f.id IN (
				SELECT DISTINCT flat_id FROM members WHERE flat_id IS NOT NULL AND is_active = true
			) AND f.id NOT IN (
				SELECT DISTINCT flat_id FROM soc_mitra_tenants WHERE status = 'ACTIVE'
			)) AS owner_occupied,
			COUNT(*) FILTER (WHERE f.id IN (
				SELECT DISTINCT flat_id FROM soc_mitra_tenants WHERE status = 'ACTIVE'
			)) AS tenant_occupied,
			COUNT(*) FILTER (WHERE f.id NOT IN (
				SELECT DISTINCT flat_id FROM members WHERE flat_id IS NOT NULL AND is_active = true
			) AND f.id NOT IN (
				SELECT DISTINCT flat_id FROM soc_mitra_tenants WHERE status = 'ACTIVE'
			)) AS vacant
		FROM flats f
	`).Scan(&result).Error
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "QUERY_FAILED"})
		return
	}
	c.JSON(http.StatusOK, result)
}

// GET /analytics/vehicle-stats
// Vehicle counts by type.
func (h *AnalyticsHandler) VehicleStats(c *gin.Context) {
	type Row struct {
		VehicleType string `json:"vehicleType"`
		Count       int64  `json:"count"`
	}

	var rows []Row
	err := h.db.Raw(`
		SELECT vehicle_type, COUNT(*) AS count
		FROM soc_mitra_vehicles
		WHERE is_active = true
		GROUP BY vehicle_type
		ORDER BY count DESC
	`).Scan(&rows).Error
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "QUERY_FAILED"})
		return
	}
	if rows == nil {
		rows = []Row{}
	}
	c.JSON(http.StatusOK, gin.H{"data": rows})
}

// GET /analytics/visitor-trends
// Daily visitor counts for last 30 days, by type.
func (h *AnalyticsHandler) VisitorTrends(c *gin.Context) {
	type DayRow struct {
		Day         string `json:"day"`
		Total       int64  `json:"total"`
		Guest       int64  `json:"guest"`
		Delivery    int64  `json:"delivery"`
		DomesticHelp int64 `json:"domesticHelp"`
		Other       int64  `json:"other"`
	}

	var rows []DayRow
	err := h.db.Raw(`
		SELECT
			TO_CHAR(DATE_TRUNC('day', created_at), 'YYYY-MM-DD') AS day,
			COUNT(*) AS total,
			COUNT(*) FILTER (WHERE visitor_type = 'GUEST')        AS guest,
			COUNT(*) FILTER (WHERE visitor_type = 'DELIVERY')     AS delivery,
			COUNT(*) FILTER (WHERE visitor_type = 'DOMESTIC_HELP') AS domestic_help,
			COUNT(*) FILTER (WHERE visitor_type NOT IN ('GUEST','DELIVERY','DOMESTIC_HELP')) AS other
		FROM soc_mitra_visitors
		WHERE created_at >= NOW() - INTERVAL '30 days'
		GROUP BY DATE_TRUNC('day', created_at)
		ORDER BY DATE_TRUNC('day', created_at)
	`).Scan(&rows).Error
	if err != nil {
		c.JSON(http.StatusInternalServerError, response.ErrorResponse{Error: err.Error(), Code: "QUERY_FAILED"})
		return
	}
	if rows == nil {
		rows = []DayRow{}
	}
	c.JSON(http.StatusOK, gin.H{"data": rows})
}

// GET /analytics/financial-summary
// Total income, expense, outstanding for current financial year.
func (h *AnalyticsHandler) FinancialSummary(c *gin.Context) {
	now := time.Now()
	var fyStart time.Time
	if now.Month() >= 4 {
		fyStart = time.Date(now.Year(), 4, 1, 0, 0, 0, 0, time.UTC)
	} else {
		fyStart = time.Date(now.Year()-1, 4, 1, 0, 0, 0, 0, time.UTC)
	}
	fyEnd := fyStart.AddDate(1, 0, 0)

	type BillSummary struct {
		TotalBilled      float64 `json:"totalBilled"`
		TotalCollected   float64 `json:"totalCollected"`
		TotalOutstanding float64 `json:"totalOutstanding"`
	}

	var bills BillSummary
	_ = h.db.Raw(`
		SELECT
			COALESCE(SUM(total_amount), 0) AS total_billed,
			COALESCE(SUM(amount_paid), 0)  AS total_collected,
			COALESCE(SUM(CASE WHEN status NOT IN ('PAID','WAIVED') THEN total_amount - amount_paid ELSE 0 END), 0) AS total_outstanding
		FROM soc_mitra_maintenance_bills
		WHERE issue_date >= ? AND issue_date < ?
	`, fyStart, fyEnd).Scan(&bills).Error

	// Get income and expense from journal lines + account head types
	type JournalSummary struct {
		TotalIncome  float64 `json:"totalIncome"`
		TotalExpense float64 `json:"totalExpense"`
	}
	var journal JournalSummary
	_ = h.db.Raw(`
		SELECT
			COALESCE(SUM(jl.credit_amount) FILTER (WHERE ah.account_type = 'INCOME'), 0)  AS total_income,
			COALESCE(SUM(jl.debit_amount)  FILTER (WHERE ah.account_type = 'EXPENSE'), 0) AS total_expense
		FROM soc_mitra_journal_lines jl
		JOIN soc_mitra_account_heads ah ON ah.id = jl.account_head_id
		JOIN soc_mitra_journal_entries je ON je.id = jl.journal_entry_id
		WHERE je.entry_date >= ? AND je.entry_date < ?
	`, fyStart, fyEnd).Scan(&journal).Error

	c.JSON(http.StatusOK, gin.H{
		"financialYearStart": fyStart.Format("2006-01-02"),
		"financialYearEnd":   fyEnd.AddDate(0, 0, -1).Format("2006-01-02"),
		"totalIncome":        journal.TotalIncome,
		"totalExpense":       journal.TotalExpense,
		"totalBilled":        bills.TotalBilled,
		"totalCollected":     bills.TotalCollected,
		"outstanding":        bills.TotalOutstanding,
	})
}
