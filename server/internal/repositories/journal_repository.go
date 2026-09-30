package repositories

import (
	"errors"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type JournalRepository struct {
	db *gorm.DB
}

func NewJournalRepository(db *gorm.DB) *JournalRepository {
	return &JournalRepository{db: db}
}

// ─── Journal Entry CRUD ─────────────────────────────────────

// Create inserts a journal entry with lines. Validates that debits == credits.
func (r *JournalRepository) Create(actor *ActorContext, je *models.JournalEntry) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	// Validate balanced entry
	var totalDebit, totalCredit float64
	for _, line := range je.Lines {
		totalDebit += line.DebitAmount
		totalCredit += line.CreditAmount
	}
	if math.Abs(totalDebit-totalCredit) > 0.01 {
		return fmt.Errorf("journal entry not balanced: debits=%.2f credits=%.2f", totalDebit, totalCredit)
	}
	if len(je.Lines) < 2 {
		return fmt.Errorf("journal entry must have at least 2 lines")
	}

	je.CreatedByID = actor.MemberID
	je.TotalAmount = totalDebit

	return r.db.Transaction(func(tx *gorm.DB) error {
		// Generate entry number
		je.EntryNo = r.nextEntryNo(tx)
		return tx.Create(je).Error
	})
}

// CreateAutomatic is used by the system to auto-generate journal entries
// for bill generation, payments, etc. Does NOT require admin — uses system context.
func (r *JournalRepository) CreateAutomatic(tx *gorm.DB, je *models.JournalEntry) error {
	var totalDebit, totalCredit float64
	for _, line := range je.Lines {
		totalDebit += line.DebitAmount
		totalCredit += line.CreditAmount
	}
	if math.Abs(totalDebit-totalCredit) > 0.01 {
		return fmt.Errorf("auto journal entry not balanced: debits=%.2f credits=%.2f", totalDebit, totalCredit)
	}
	je.TotalAmount = totalDebit
	je.IsAutomatic = true
	je.EntryNo = r.nextEntryNo(tx)
	return tx.Create(je).Error
}

// List returns journal entries with optional date range filter. Admin-only.
func (r *JournalRepository) List(actor *ActorContext, from, to *time.Time) ([]models.JournalEntry, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	q := r.db.Preload("Lines.AccountHead").Order("entry_date DESC, entry_no DESC")
	if from != nil {
		q = q.Where("entry_date >= ?", *from)
	}
	if to != nil {
		q = q.Where("entry_date <= ?", *to)
	}
	var rows []models.JournalEntry
	err := q.Find(&rows).Error
	return rows, err
}

// GetByID returns a single journal entry with lines.
func (r *JournalRepository) GetByID(id uuid.UUID) (*models.JournalEntry, error) {
	var je models.JournalEntry
	err := r.db.Preload("Lines.AccountHead").First(&je, "id = ?", id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &je, nil
}

// GetByRef returns journal entries for a given source reference (e.g., a bill or payment).
func (r *JournalRepository) GetByRef(refType string, refID uuid.UUID) ([]models.JournalEntry, error) {
	var rows []models.JournalEntry
	err := r.db.Preload("Lines.AccountHead").
		Where("ref_type = ? AND ref_id = ?", refType, refID).
		Order("entry_date ASC").
		Find(&rows).Error
	return rows, err
}

// ─── Ledger Queries ─────────────────────────────────────────

// LedgerEntry represents a single row in an account's ledger view.
type LedgerEntry struct {
	Date            time.Time `json:"date"`
	EntryNo         string    `json:"entryNo"`
	Narration       string    `json:"narration"`
	CounterAccount  string    `json:"counterAccount"`
	DebitAmount     float64   `json:"debitAmount"`
	CreditAmount    float64   `json:"creditAmount"`
	RunningBalance  float64   `json:"runningBalance"`
	JournalEntryID  uuid.UUID `json:"journalEntryId"`
}

// GetLedger returns all journal lines for a specific account, ordered by date.
func (r *JournalRepository) GetLedger(actor *ActorContext, accountID uuid.UUID, from, to *time.Time) ([]LedgerEntry, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}

	q := r.db.Table("soc_mitra_journal_lines jl").
		Select("je.entry_date, je.entry_no, je.narration, jl.debit_amount, jl.credit_amount, jl.journal_entry_id").
		Joins("JOIN soc_mitra_journal_entries je ON je.id = jl.journal_entry_id").
		Where("jl.account_head_id = ?", accountID).
		Order("je.entry_date ASC, je.entry_no ASC")

	if from != nil {
		q = q.Where("je.entry_date >= ?", *from)
	}
	if to != nil {
		q = q.Where("je.entry_date <= ?", *to)
	}

	type rawRow struct {
		EntryDate      time.Time
		EntryNo        string
		Narration      string
		DebitAmount    float64
		CreditAmount   float64
		JournalEntryID uuid.UUID
	}

	var rows []rawRow
	if err := q.Find(&rows).Error; err != nil {
		return nil, err
	}

	var balance float64
	result := make([]LedgerEntry, len(rows))
	for i, row := range rows {
		balance += row.DebitAmount - row.CreditAmount
		result[i] = LedgerEntry{
			Date:           row.EntryDate,
			EntryNo:        row.EntryNo,
			Narration:      row.Narration,
			DebitAmount:    row.DebitAmount,
			CreditAmount:   row.CreditAmount,
			RunningBalance: balance,
			JournalEntryID: row.JournalEntryID,
		}
	}
	return result, nil
}

// AccountBalance returns the total debit - credit for an account.
func (r *JournalRepository) AccountBalance(accountID uuid.UUID) (float64, error) {
	var result struct {
		Balance float64
	}
	err := r.db.Table("soc_mitra_journal_lines").
		Select("COALESCE(SUM(debit_amount), 0) - COALESCE(SUM(credit_amount), 0) as balance").
		Where("account_head_id = ?", accountID).
		Scan(&result).Error
	return result.Balance, err
}

// TrialBalance returns debit/credit totals for all accounts.
type TrialBalanceRow struct {
	AccountID    uuid.UUID `json:"accountId"`
	AccountCode  string    `json:"accountCode"`
	AccountName  string    `json:"accountName"`
	AccountType  string    `json:"accountType"`
	TotalDebit   float64   `json:"totalDebit"`
	TotalCredit  float64   `json:"totalCredit"`
	Balance      float64   `json:"balance"`
}

func (r *JournalRepository) TrialBalance(actor *ActorContext, from, to *time.Time) ([]TrialBalanceRow, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}

	q := r.db.Table("soc_mitra_journal_lines jl").
		Select(`ah.id as account_id, ah.code as account_code, ah.name as account_name, ah.type as account_type,
			COALESCE(SUM(jl.debit_amount), 0) as total_debit,
			COALESCE(SUM(jl.credit_amount), 0) as total_credit,
			COALESCE(SUM(jl.debit_amount), 0) - COALESCE(SUM(jl.credit_amount), 0) as balance`).
		Joins("JOIN soc_mitra_account_heads ah ON ah.id = jl.account_head_id").
		Joins("JOIN soc_mitra_journal_entries je ON je.id = jl.journal_entry_id").
		Group("ah.id, ah.code, ah.name, ah.type").
		Order("ah.code ASC")

	if from != nil {
		q = q.Where("je.entry_date >= ?", *from)
	}
	if to != nil {
		q = q.Where("je.entry_date <= ?", *to)
	}

	var rows []TrialBalanceRow
	err := q.Find(&rows).Error
	return rows, err
}

// ─── Helpers ────────────────────────────────────────────────

func (r *JournalRepository) nextEntryNo(tx *gorm.DB) string {
	year := time.Now().Year()
	var count int64
	tx.Model(&models.JournalEntry{}).
		Where("EXTRACT(YEAR FROM entry_date) = ?", year).
		Count(&count)
	return fmt.Sprintf("JE-%d-%04d", year, count+1)
}
