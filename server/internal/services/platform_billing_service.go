package services

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

// IST is the Indian Standard Time location used for billing date calculations.
var IST *time.Location

func init() {
	var err error
	IST, err = time.LoadLocation("Asia/Kolkata")
	if err != nil {
		// Fallback: UTC+5:30
		IST = time.FixedZone("IST", 5*3600+30*60)
	}
}

type PlatformBillingService struct {
	db *gorm.DB
}

func NewPlatformBillingService(db *gorm.DB) *PlatformBillingService {
	return &PlatformBillingService{db: db}
}

// ─── Daily Billing Run ──────────────────────────────────────────────────────

// RunDailyBilling checks all active billing configs and generates invoices
// for societies whose billing day falls today. It is idempotent.
func (s *PlatformBillingService) RunDailyBilling() error {
	today := time.Now().In(IST)
	log.Printf("[Billing] Starting daily billing run for %s", today.Format("2006-01-02"))

	var configs []models.PlatformBillingConfig
	if err := s.db.Preload("Society").Where("is_active = ?", true).Find(&configs).Error; err != nil {
		return fmt.Errorf("failed to load billing configs: %w", err)
	}

	var billed int
	var totalAmt float64
	type runResult struct {
		SocietyID   string  `json:"societyId"`
		SocietyName string  `json:"societyName"`
		InvoiceNo   string  `json:"invoiceNo,omitempty"`
		Amount      float64 `json:"amount,omitempty"`
		Error       string  `json:"error,omitempty"`
	}
	var results []runResult

	for i := range configs {
		cfg := &configs[i]

		// Skip if billing hasn't started yet
		if today.Before(cfg.StartBillingFrom) {
			continue
		}

		if !IsBillingDay(*cfg, today) {
			continue
		}

		if cfg.Society == nil {
			continue
		}

		// Update overdue status on old invoices first
		s.updateOverdueInvoices(cfg.SocietyID, today)

		inv, err := s.GenerateInvoice(cfg, *cfg.Society, today)
		if err != nil {
			log.Printf("[Billing] Error generating invoice for society %s: %v", cfg.SocietyID, err)
			results = append(results, runResult{
				SocietyID:   cfg.SocietyID.String(),
				SocietyName: cfg.Society.Name,
				Error:       err.Error(),
			})
			continue
		}
		if inv == nil {
			// Already generated for this period
			continue
		}

		billed++
		totalAmt += inv.TotalAmount
		results = append(results, runResult{
			SocietyID:   cfg.SocietyID.String(),
			SocietyName: cfg.Society.Name,
			InvoiceNo:   inv.InvoiceNo,
			Amount:      inv.TotalAmount,
		})
	}

	// Log audit entry
	auditStatus := "SUCCESS"
	if billed == 0 && len(results) > 0 {
		auditStatus = "FAILED"
	} else if billed > 0 && billed < len(results) {
		auditStatus = "PARTIAL_FAILURE"
	}

	detailsJSON, _ := json.Marshal(results)
	audit := &models.PlatformBillingAudit{
		RunDate:         today,
		RunType:         "SCHEDULED",
		SocietiesBilled: billed,
		TotalAmount:     totalAmt,
		Status:          auditStatus,
		Details:         string(detailsJSON),
	}
	s.db.Create(audit)

	log.Printf("[Billing] Run complete: %d societies billed, total %.2f", billed, totalAmt)
	return nil
}

// RunManualBilling triggers a billing run manually (same logic, different audit tag).
func (s *PlatformBillingService) RunManualBilling() error {
	today := time.Now().In(IST)
	log.Printf("[Billing] Manual billing run triggered for %s", today.Format("2006-01-02"))

	var configs []models.PlatformBillingConfig
	if err := s.db.Preload("Society").Where("is_active = ?", true).Find(&configs).Error; err != nil {
		return fmt.Errorf("failed to load billing configs: %w", err)
	}

	var billed int
	var totalAmt float64
	type runResult struct {
		SocietyID   string  `json:"societyId"`
		SocietyName string  `json:"societyName"`
		InvoiceNo   string  `json:"invoiceNo,omitempty"`
		Amount      float64 `json:"amount,omitempty"`
		Error       string  `json:"error,omitempty"`
	}
	var results []runResult

	for i := range configs {
		cfg := &configs[i]
		if today.Before(cfg.StartBillingFrom) {
			continue
		}
		if cfg.Society == nil {
			continue
		}

		s.updateOverdueInvoices(cfg.SocietyID, today)

		inv, err := s.GenerateInvoice(cfg, *cfg.Society, today)
		if err != nil {
			results = append(results, runResult{
				SocietyID:   cfg.SocietyID.String(),
				SocietyName: cfg.Society.Name,
				Error:       err.Error(),
			})
			continue
		}
		if inv == nil {
			continue
		}

		billed++
		totalAmt += inv.TotalAmount
		results = append(results, runResult{
			SocietyID:   cfg.SocietyID.String(),
			SocietyName: cfg.Society.Name,
			InvoiceNo:   inv.InvoiceNo,
			Amount:      inv.TotalAmount,
		})
	}

	auditStatus := "SUCCESS"
	if billed == 0 && len(results) > 0 {
		auditStatus = "FAILED"
	}
	detailsJSON, _ := json.Marshal(results)
	audit := &models.PlatformBillingAudit{
		RunDate:         today,
		RunType:         "MANUAL",
		SocietiesBilled: billed,
		TotalAmount:     totalAmt,
		Status:          auditStatus,
		Details:         string(detailsJSON),
	}
	s.db.Create(audit)

	return nil
}

// ─── Invoice Generation ─────────────────────────────────────────────────────

// GenerateInvoice creates a single invoice for a society. Returns nil (no error)
// if an invoice already exists for this billing period (idempotent).
func (s *PlatformBillingService) GenerateInvoice(config *models.PlatformBillingConfig, society models.PlatformSociety, today time.Time) (*models.PlatformInvoice, error) {
	billingPeriod := today.Format("Jan 2006") // e.g. "Oct 2026"
	periodStart := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, IST)
	periodEnd := periodStart.AddDate(0, 1, -1) // last day of month

	// Idempotency check
	var existing models.PlatformInvoice
	err := s.db.Where("society_id = ? AND billing_period = ?", config.SocietyID, billingPeriod).First(&existing).Error
	if err == nil {
		return nil, nil // already generated
	}

	totalFlats := society.TotalFlats
	if totalFlats <= 0 {
		totalFlats = 1
	}

	baseAmount := float64(totalFlats) * config.RatePerFlat

	var gstPercent, gstAmount float64
	if config.GSTApplicable {
		gstPercent = 18.0
		gstAmount = roundTo2(baseAmount * gstPercent / 100)
	}

	arrears := s.CalculateArrears(config.SocietyID)
	interest := s.CalculateInterest(config.SocietyID, config.InterestRate, config.GraceDays)
	totalAmount := roundTo2(baseAmount + gstAmount + arrears + interest)

	dueDate := today.AddDate(0, 0, config.DueDays)

	invoiceNo := s.GenerateInvoiceNumber(config)

	inv := &models.PlatformInvoice{
		SocietyID:      config.SocietyID,
		InvoiceNo:      invoiceNo,
		BillingPeriod:  billingPeriod,
		PeriodStart:    periodStart,
		PeriodEnd:      periodEnd,
		TotalFlats:     totalFlats,
		RatePerFlat:    config.RatePerFlat,
		BaseAmount:     baseAmount,
		GSTPercent:     gstPercent,
		GSTAmount:      gstAmount,
		Arrears:        arrears,
		InterestAmount: interest,
		TotalAmount:    totalAmount,
		DueDate:        dueDate,
		Status:         models.InvoiceGenerated,
	}

	if err := s.db.Create(inv).Error; err != nil {
		return nil, fmt.Errorf("create invoice: %w", err)
	}

	// Increment sequence atomically
	s.db.Model(config).Update("next_sequence", gorm.Expr("next_sequence + 1"))

	return inv, nil
}

// ─── Arrears & Interest ─────────────────────────────────────────────────────

// CalculateArrears sums unpaid amounts from previous invoices.
func (s *PlatformBillingService) CalculateArrears(societyID uuid.UUID) float64 {
	var total float64
	s.db.Model(&models.PlatformInvoice{}).
		Where("society_id = ? AND status IN ?", societyID, []string{
			string(models.InvoiceGenerated),
			string(models.InvoiceOverdue),
			string(models.InvoicePartiallyPaid),
		}).
		Select("COALESCE(SUM(total_amount - paid_amount), 0)").
		Scan(&total)
	return roundTo2(total)
}

// CalculateInterest computes simple interest on overdue invoices
// past due_date + grace_days.
func (s *PlatformBillingService) CalculateInterest(societyID uuid.UUID, annualRate float64, graceDays int) float64 {
	now := time.Now().In(IST)

	var invoices []models.PlatformInvoice
	s.db.Where("society_id = ? AND status IN ?", societyID, []string{
		string(models.InvoiceOverdue),
		string(models.InvoicePartiallyPaid),
	}).Find(&invoices)

	var totalInterest float64
	for _, inv := range invoices {
		graceEnd := inv.DueDate.AddDate(0, 0, graceDays)
		if now.Before(graceEnd) {
			continue
		}
		daysOverdue := int(now.Sub(graceEnd).Hours() / 24)
		if daysOverdue <= 0 {
			continue
		}
		overdueAmount := inv.TotalAmount - inv.PaidAmount
		if overdueAmount <= 0 {
			continue
		}
		interest := overdueAmount * annualRate / 100 * float64(daysOverdue) / 365
		totalInterest += interest
	}
	return roundTo2(totalInterest)
}

// ─── Invoice Number ─────────────────────────────────────────────────────────

// GenerateInvoiceNumber produces "PREFIX/YYYY-YY/SEQ" format.
// Financial year: Apr-Mar. If month >= April, year is current/next. Else previous/current.
func (s *PlatformBillingService) GenerateInvoiceNumber(config *models.PlatformBillingConfig) string {
	now := time.Now().In(IST)
	var startYear, endYear int
	if now.Month() >= time.April {
		startYear = now.Year()
		endYear = now.Year() + 1
	} else {
		startYear = now.Year() - 1
		endYear = now.Year()
	}
	fyStr := fmt.Sprintf("%d-%02d", startYear, endYear%100)
	seqStr := fmt.Sprintf("%03d", config.NextSequence)
	return fmt.Sprintf("%s/%s/%s", config.BillPrefix, fyStr, seqStr)
}

// ─── Mark Paid ──────────────────────────────────────────────────────────────

func (s *PlatformBillingService) MarkPaid(invoiceID uuid.UUID, amount float64, mode, ref, notes string) error {
	var inv models.PlatformInvoice
	if err := s.db.First(&inv, "id = ?", invoiceID).Error; err != nil {
		return fmt.Errorf("invoice not found: %w", err)
	}

	now := time.Now().In(IST)
	inv.PaidAmount += amount
	inv.PaidDate = &now
	inv.PaymentRef = ref
	inv.PaymentMode = mode
	if notes != "" {
		inv.Notes = notes
	}

	if inv.PaidAmount >= inv.TotalAmount {
		inv.Status = models.InvoicePaid
	} else {
		inv.Status = models.InvoicePartiallyPaid
	}

	return s.db.Save(&inv).Error
}

// ─── Billing Day Check ──────────────────────────────────────────────────────

// IsBillingDay checks if today is the billing day for a given config.
func IsBillingDay(config models.PlatformBillingConfig, today time.Time) bool {
	switch config.BillingCycle {
	case models.BillingCycleMonthEnd:
		// Last day of month
		tomorrow := today.AddDate(0, 0, 1)
		return tomorrow.Day() == 1
	case models.BillingCycleAnniversary:
		return today.Day() == config.BillingDay
	default:
		return false
	}
}

// ─── Overdue Status Update ──────────────────────────────────────────────────

func (s *PlatformBillingService) updateOverdueInvoices(societyID uuid.UUID, today time.Time) {
	s.db.Model(&models.PlatformInvoice{}).
		Where("society_id = ? AND status = ? AND due_date < ?",
			societyID, models.InvoiceGenerated, today).
		Update("status", models.InvoiceOverdue)
}

// ─── Query Helpers ──────────────────────────────────────────────────────────

func (s *PlatformBillingService) ListConfigs() ([]models.PlatformBillingConfig, error) {
	var configs []models.PlatformBillingConfig
	err := s.db.Preload("Society").Order("created_at DESC").Find(&configs).Error
	return configs, err
}

func (s *PlatformBillingService) GetConfig(id uuid.UUID) (*models.PlatformBillingConfig, error) {
	var cfg models.PlatformBillingConfig
	if err := s.db.Preload("Society").First(&cfg, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &cfg, nil
}

func (s *PlatformBillingService) UpdateConfig(id uuid.UUID, updates map[string]interface{}) error {
	return s.db.Model(&models.PlatformBillingConfig{}).Where("id = ?", id).Updates(updates).Error
}

func (s *PlatformBillingService) ListInvoices(societyID *uuid.UUID, status *string, period *string) ([]models.PlatformInvoice, error) {
	q := s.db.Preload("Society").Order("created_at DESC")
	if societyID != nil {
		q = q.Where("society_id = ?", *societyID)
	}
	if status != nil && *status != "" {
		q = q.Where("status = ?", *status)
	}
	if period != nil && *period != "" {
		q = q.Where("billing_period = ?", *period)
	}
	var invoices []models.PlatformInvoice
	err := q.Find(&invoices).Error
	return invoices, err
}

func (s *PlatformBillingService) GetInvoice(id uuid.UUID) (*models.PlatformInvoice, error) {
	var inv models.PlatformInvoice
	if err := s.db.Preload("Society").First(&inv, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &inv, nil
}

func (s *PlatformBillingService) ListAudits(limit int) ([]models.PlatformBillingAudit, error) {
	if limit <= 0 {
		limit = 50
	}
	var audits []models.PlatformBillingAudit
	err := s.db.Order("created_at DESC").Limit(limit).Find(&audits).Error
	return audits, err
}

// BillingSummary returns revenue summary stats.
type BillingSummary struct {
	TotalMonthlyRevenue float64 `json:"totalMonthlyRevenue"`
	OutstandingAmount   float64 `json:"outstandingAmount"`
	CollectedThisMonth  float64 `json:"collectedThisMonth"`
	TotalBilled         float64 `json:"totalBilled"`
	TotalCollected      float64 `json:"totalCollected"`
}

func (s *PlatformBillingService) GetSummary() (*BillingSummary, error) {
	summary := &BillingSummary{}

	// Total monthly revenue = sum of active configs * their society's total_flats
	type configFlat struct {
		RatePerFlat float64
		TotalFlats  int
	}
	var cfs []configFlat
	s.db.Raw(`
		SELECT c.rate_per_flat, s.total_flats
		FROM platform_billing_configs c
		JOIN platform_societies s ON s.id = c.society_id
		WHERE c.is_active = true AND s.status = 'ACTIVE'
	`).Scan(&cfs)
	for _, cf := range cfs {
		summary.TotalMonthlyRevenue += cf.RatePerFlat * float64(cf.TotalFlats)
	}

	// Outstanding = unpaid invoice amounts
	s.db.Model(&models.PlatformInvoice{}).
		Where("status IN ?", []string{
			string(models.InvoiceGenerated),
			string(models.InvoiceOverdue),
			string(models.InvoicePartiallyPaid),
		}).
		Select("COALESCE(SUM(total_amount - paid_amount), 0)").
		Scan(&summary.OutstandingAmount)

	// Collected this month
	now := time.Now().In(IST)
	monthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, IST)
	s.db.Model(&models.PlatformInvoice{}).
		Where("paid_date >= ?", monthStart).
		Select("COALESCE(SUM(paid_amount), 0)").
		Scan(&summary.CollectedThisMonth)

	// Total billed ever
	s.db.Model(&models.PlatformInvoice{}).
		Select("COALESCE(SUM(total_amount), 0)").
		Scan(&summary.TotalBilled)

	// Total collected ever
	s.db.Model(&models.PlatformInvoice{}).
		Select("COALESCE(SUM(paid_amount), 0)").
		Scan(&summary.TotalCollected)

	return summary, nil
}

// ─── Generate Bill Prefix ───────────────────────────────────────────────────

// BillPrefixFromSlug returns first 6 chars of slug uppercased.
func BillPrefixFromSlug(slug string) string {
	s := strings.ToUpper(strings.ReplaceAll(slug, "-", ""))
	if len(s) > 6 {
		s = s[:6]
	}
	return s
}

// ─── Helpers ────────────────────────────────────────────────────────────────

func roundTo2(v float64) float64 {
	return math.Round(v*100) / 100
}
