package repositories

import (
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type VendorPaymentRepository struct {
	db      *gorm.DB
	journal *JournalRepository
}

func NewVendorPaymentRepository(db *gorm.DB, journal *JournalRepository) *VendorPaymentRepository {
	return &VendorPaymentRepository{db: db, journal: journal}
}

// List returns all vendor payments. Admin-only.
func (r *VendorPaymentRepository) List(actor *ActorContext) ([]models.VendorPayment, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var rows []models.VendorPayment
	err := r.db.Preload("Vendor").
		Order("payment_date DESC").
		Find(&rows).Error
	return rows, err
}

// GetByID returns a single vendor payment.
func (r *VendorPaymentRepository) GetByID(actor *ActorContext, id uuid.UUID) (*models.VendorPayment, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var vp models.VendorPayment
	err := r.db.Preload("Vendor").First(&vp, "id = ?", id).Error
	return &vp, err
}

// Create records a vendor payment with automatic TDS deduction and journal entry.
func (r *VendorPaymentRepository) Create(actor *ActorContext, vp *models.VendorPayment) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}

	// Fetch vendor for TDS details
	var vendor models.Vendor
	if err := r.db.First(&vendor, "id = ?", vp.VendorID).Error; err != nil {
		return fmt.Errorf("vendor not found: %w", err)
	}

	// Auto-calculate TDS
	if vp.TDSSection == "" {
		vp.TDSSection = vendor.TDSSection
	}
	if vp.TDSRate == 0 {
		vp.TDSRate = vendor.TDSRate
	}

	// TDS is deducted on gross amount (excluding GST for TDS purposes)
	vp.TDSAmount = math.Round(vp.GrossAmount*vp.TDSRate) / 100
	vp.NetAmount = vp.GrossAmount - vp.TDSAmount

	vp.CreatedByID = &actor.UserID

	// Create in transaction with journal entry
	return r.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(vp).Error; err != nil {
			return err
		}

		// Create journal entry if expense account is set
		if vp.ExpenseAccountID != nil && r.journal != nil {
			// Look up the TDS payable account by section
			tdsAccountCode := tdsAccountForSection(vp.TDSSection)
			var tdsAccount models.AccountHead
			hasTDS := vp.TDSAmount > 0

			if hasTDS {
				if err := tx.Where("code = ?", tdsAccountCode).First(&tdsAccount).Error; err != nil {
					// If TDS account doesn't exist, skip TDS journal line
					hasTDS = false
				}
			}

			// Bank account (default 1101 - SBI Savings)
			var bankAccount models.AccountHead
			if err := tx.Where("code = ?", "1101").First(&bankAccount).Error; err != nil {
				return nil // skip journal if bank account not found
			}

			lines := []models.JournalLine{
				{DebitAmount: vp.GrossAmount, CreditAmount: 0, AccountHeadID: *vp.ExpenseAccountID},    // Dr. Expense
				{DebitAmount: 0, CreditAmount: vp.NetAmount, AccountHeadID: bankAccount.ID},              // Cr. Bank
			}
			if hasTDS {
				lines = append(lines, models.JournalLine{
					DebitAmount: 0, CreditAmount: vp.TDSAmount, AccountHeadID: tdsAccount.ID, // Cr. TDS Payable
				})
			}

			refID := vp.ID
			entry := &models.JournalEntry{
				EntryDate:   vp.PaymentDate,
				Narration:   fmt.Sprintf("Payment to %s - %s", vendor.Name, vp.Narration),
				NarrationMr: vp.NarrationMr,
				RefType:     "VENDOR_PAYMENT",
				RefID:       &refID,
				TotalAmount: vp.GrossAmount,
				IsAutomatic: true,
				Lines:       lines,
			}

			if err := tx.Create(entry).Error; err != nil {
				return fmt.Errorf("journal entry failed: %w", err)
			}
			vp.JournalEntryID = &entry.ID
			tx.Model(vp).Update("journal_entry_id", entry.ID)
		}

		return nil
	})
}

// MarkTDSDeposited records the TDS challan details when TDS is deposited with government.
func (r *VendorPaymentRepository) MarkTDSDeposited(actor *ActorContext, id uuid.UUID, challanNo string, depositDate time.Time) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.VendorPayment{}).Where("id = ?", id).
		Updates(map[string]interface{}{
			"tds_deposited":   true,
			"tds_challan_no":  challanNo,
			"tds_deposit_date": depositDate,
		}).Error
}

// TDSSummary returns TDS payable summary by section.
type TDSSummary struct {
	Section        string  `json:"section"`
	TotalDeducted  float64 `json:"totalDeducted"`
	TotalDeposited float64 `json:"totalDeposited"`
	Pending        float64 `json:"pending"`
	PaymentCount   int     `json:"paymentCount"`
}

func (r *VendorPaymentRepository) GetTDSSummary(actor *ActorContext) ([]TDSSummary, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}

	var rows []TDSSummary
	err := r.db.Table("soc_mitra_vendor_payments").
		Select(`tds_section as section,
			COALESCE(SUM(tds_amount), 0) as total_deducted,
			COALESCE(SUM(CASE WHEN tds_deposited = true THEN tds_amount ELSE 0 END), 0) as total_deposited,
			COALESCE(SUM(CASE WHEN tds_deposited = false THEN tds_amount ELSE 0 END), 0) as pending,
			COUNT(*) as payment_count`).
		Where("tds_amount > 0").
		Group("tds_section").
		Order("tds_section ASC").
		Scan(&rows).Error
	return rows, err
}

// GetPendingTDSPayments returns vendor payments where TDS is deducted but not yet deposited.
func (r *VendorPaymentRepository) GetPendingTDSPayments(actor *ActorContext) ([]models.VendorPayment, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}
	var rows []models.VendorPayment
	err := r.db.Preload("Vendor").
		Where("tds_amount > 0 AND tds_deposited = false").
		Order("payment_date ASC").
		Find(&rows).Error
	return rows, err
}

// tdsAccountForSection returns the account code for TDS payable by section.
func tdsAccountForSection(section string) string {
	switch section {
	case "194C":
		return "2401" // TDS Payable - 194C
	case "194J":
		return "2402" // TDS Payable - 194J
	case "194I":
		return "2403" // TDS Payable - 194I
	default:
		return "2401" // TDS Payable - 194C (fallback)
	}
}
