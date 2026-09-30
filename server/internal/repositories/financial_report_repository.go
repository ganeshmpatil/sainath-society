package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type FinancialReportRepository struct {
	db *gorm.DB
}

func NewFinancialReportRepository(db *gorm.DB) *FinancialReportRepository {
	return &FinancialReportRepository{db: db}
}

// ─── Income & Expenditure Statement ────────────────────────

// IELineItem represents one row in the I&E statement.
type IELineItem struct {
	AccountID   uuid.UUID `json:"accountId"`
	AccountCode string    `json:"accountCode"`
	AccountName string    `json:"accountName"`
	AccountNameMr string  `json:"accountNameMr"`
	Amount      float64   `json:"amount"`
}

// IEStatement holds the complete Income & Expenditure statement.
type IEStatement struct {
	PeriodFrom  string       `json:"periodFrom"`
	PeriodTo    string       `json:"periodTo"`
	Income      []IELineItem `json:"income"`
	Expenses    []IELineItem `json:"expenses"`
	TotalIncome float64      `json:"totalIncome"`
	TotalExpense float64     `json:"totalExpense"`
	Surplus     float64      `json:"surplus"` // positive = surplus, negative = deficit
}

// GetIncomeExpenditure generates the I&E statement for a date range.
// Uses journal entries to calculate actual income/expense by account head.
func (r *FinancialReportRepository) GetIncomeExpenditure(actor *ActorContext, from, to time.Time) (*IEStatement, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}

	// Query journal lines grouped by account head, filtered by income/expense types
	type row struct {
		AccountID     uuid.UUID
		AccountCode   string
		AccountName   string
		AccountNameMr string
		AccountType   string
		TotalDebit    float64
		TotalCredit   float64
	}

	var rows []row
	err := r.db.Table("soc_mitra_journal_lines jl").
		Select(`ah.id as account_id, ah.code as account_code, ah.name as account_name,
			ah.name_mr as account_name_mr, ah.type as account_type,
			COALESCE(SUM(jl.debit_amount), 0) as total_debit,
			COALESCE(SUM(jl.credit_amount), 0) as total_credit`).
		Joins("JOIN soc_mitra_account_heads ah ON ah.id = jl.account_head_id").
		Joins("JOIN soc_mitra_journal_entries je ON je.id = jl.journal_entry_id").
		Where("ah.type IN ? AND je.entry_date >= ? AND je.entry_date <= ? AND ah.is_group = ?",
			[]string{"INCOME", "EXPENSE"}, from, to, false).
		Group("ah.id, ah.code, ah.name, ah.name_mr, ah.type").
		Order("ah.code ASC").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	stmt := &IEStatement{
		PeriodFrom: from.Format("2006-01-02"),
		PeriodTo:   to.Format("2006-01-02"),
	}

	for _, r := range rows {
		switch r.AccountType {
		case "INCOME":
			// Income accounts: credit is income
			amount := r.TotalCredit - r.TotalDebit
			if amount != 0 {
				stmt.Income = append(stmt.Income, IELineItem{
					AccountID:     r.AccountID,
					AccountCode:   r.AccountCode,
					AccountName:   r.AccountName,
					AccountNameMr: r.AccountNameMr,
					Amount:        amount,
				})
				stmt.TotalIncome += amount
			}
		case "EXPENSE":
			// Expense accounts: debit is expense
			amount := r.TotalDebit - r.TotalCredit
			if amount != 0 {
				stmt.Expenses = append(stmt.Expenses, IELineItem{
					AccountID:     r.AccountID,
					AccountCode:   r.AccountCode,
					AccountName:   r.AccountName,
					AccountNameMr: r.AccountNameMr,
					Amount:        amount,
				})
				stmt.TotalExpense += amount
			}
		}
	}

	stmt.Surplus = stmt.TotalIncome - stmt.TotalExpense
	return stmt, nil
}

// ─── Collection Dashboard ──────────────────────────────────

// CollectionStats provides collection efficiency metrics.
type CollectionStats struct {
	TotalBilled      float64            `json:"totalBilled"`
	TotalCollected   float64            `json:"totalCollected"`
	CollectionRate   float64            `json:"collectionRate"` // percentage
	OnTimePayments   int                `json:"onTimePayments"`
	TotalBills       int                `json:"totalBills"`
	OnTimeRate       float64            `json:"onTimeRate"`
	WingWise         []WingCollection   `json:"wingWise"`
	MonthlyTrend     []MonthlyCollection `json:"monthlyTrend"`
}

type WingCollection struct {
	WingName       string  `json:"wingName"`
	TotalBilled    float64 `json:"totalBilled"`
	TotalCollected float64 `json:"totalCollected"`
	CollectionRate float64 `json:"collectionRate"`
}

type MonthlyCollection struct {
	Period    string  `json:"period"` // "2026-04"
	Billed   float64 `json:"billed"`
	Collected float64 `json:"collected"`
	Rate     float64 `json:"rate"`
}

// GetCollectionStats calculates collection efficiency metrics.
func (r *FinancialReportRepository) GetCollectionStats(actor *ActorContext) (*CollectionStats, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}

	stats := &CollectionStats{}

	// Overall stats
	r.db.Table("soc_mitra_maintenance_bills").
		Select("COALESCE(SUM(total_amount), 0) as total_billed, COALESCE(SUM(amount_paid), 0) as total_collected, COUNT(*) as total_bills").
		Row().Scan(&stats.TotalBilled, &stats.TotalCollected, &stats.TotalBills)

	if stats.TotalBilled > 0 {
		stats.CollectionRate = (stats.TotalCollected / stats.TotalBilled) * 100
	}

	// On-time payments (paid before or on due date)
	var onTimeCount int64
	r.db.Table("soc_mitra_maintenance_bills").
		Where("status = ? AND paid_at IS NOT NULL AND paid_at <= due_date", "PAID").
		Count(&onTimeCount)
	stats.OnTimePayments = int(onTimeCount)

	var paidBills int64
	r.db.Table("soc_mitra_maintenance_bills").Where("status = ?", "PAID").Count(&paidBills)
	if paidBills > 0 {
		stats.OnTimeRate = (float64(stats.OnTimePayments) / float64(paidBills)) * 100
	}

	// Wing-wise collection
	type wingRow struct {
		WingName       string
		TotalBilled    float64
		TotalCollected float64
	}
	var wings []wingRow
	r.db.Table("soc_mitra_maintenance_bills b").
		Select("COALESCE(w.name, 'Unknown') as wing_name, COALESCE(SUM(b.total_amount), 0) as total_billed, COALESCE(SUM(b.amount_paid), 0) as total_collected").
		Joins("JOIN flats f ON f.id = b.flat_id").
		Joins("LEFT JOIN wings w ON w.id = f.wing_id").
		Group("w.name").
		Order("w.name ASC").
		Scan(&wings)

	for _, w := range wings {
		rate := 0.0
		if w.TotalBilled > 0 {
			rate = (w.TotalCollected / w.TotalBilled) * 100
		}
		stats.WingWise = append(stats.WingWise, WingCollection{
			WingName:       w.WingName,
			TotalBilled:    w.TotalBilled,
			TotalCollected: w.TotalCollected,
			CollectionRate: rate,
		})
	}

	// Monthly trend (last 12 months)
	type monthRow struct {
		Period    string
		Billed   float64
		Collected float64
	}
	var months []monthRow
	r.db.Table("soc_mitra_maintenance_bills").
		Select("billing_period as period, COALESCE(SUM(total_amount), 0) as billed, COALESCE(SUM(amount_paid), 0) as collected").
		Group("billing_period").
		Order("billing_period DESC").
		Limit(12).
		Scan(&months)

	for i := len(months) - 1; i >= 0; i-- {
		m := months[i]
		rate := 0.0
		if m.Billed > 0 {
			rate = (m.Collected / m.Billed) * 100
		}
		stats.MonthlyTrend = append(stats.MonthlyTrend, MonthlyCollection{
			Period:    m.Period,
			Billed:   m.Billed,
			Collected: m.Collected,
			Rate:     rate,
		})
	}

	return stats, nil
}
