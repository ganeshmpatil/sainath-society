package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type DefaulterRepository struct {
	db *gorm.DB
}

func NewDefaulterRepository(db *gorm.DB) *DefaulterRepository {
	return &DefaulterRepository{db: db}
}

// DefaulterRow represents one member's defaulter status.
type DefaulterRow struct {
	MemberID    uuid.UUID `json:"memberId"`
	MemberName  string    `json:"memberName"`
	FlatID      uuid.UUID `json:"flatId"`
	FlatNumber  string    `json:"flatNumber"`
	WingName    string    `json:"wingName"`
	TotalBills  int       `json:"totalBills"`
	TotalAmount float64   `json:"totalAmount"`
	AmountPaid  float64   `json:"amountPaid"`
	Outstanding float64   `json:"outstanding"`
	InterestDue float64   `json:"interestDue"`
	// Aging buckets (outstanding amount in each range)
	Bucket0to30  float64 `json:"bucket0to30"`
	Bucket31to60 float64 `json:"bucket31to60"`
	Bucket61to90 float64 `json:"bucket61to90"`
	Bucket90Plus float64 `json:"bucket90Plus"`
	OldestDueDate *time.Time `json:"oldestDueDate"`
	DaysOverdue   int        `json:"daysOverdue"`
	IsDefaulter   bool       `json:"isDefaulter"` // >90 days overdue per MCS Act
}

// GetDefaulterRegister returns all members with outstanding dues, with aging buckets.
func (r *DefaulterRepository) GetDefaulterRegister(actor *ActorContext) ([]DefaulterRow, error) {
	if !actor.IsAdmin() {
		return nil, ErrForbidden
	}

	now := time.Now()

	// Get all unpaid bills with flat and member info
	type billRow struct {
		MemberID   uuid.UUID
		MemberName string
		FlatID     uuid.UUID
		FlatNumber string
		WingName   string
		DueDate    time.Time
		TotalAmount float64
		AmountPaid  float64
		InterestAmount float64
	}

	var bills []billRow
	err := r.db.Table("soc_mitra_maintenance_bills b").
		Select(`b.member_id, m.name as member_name, b.flat_id, f.flat_number,
			COALESCE(w.name, '') as wing_name, b.due_date,
			b.total_amount, b.amount_paid, b.interest_amount`).
		Joins("JOIN members m ON m.id = b.member_id").
		Joins("JOIN flats f ON f.id = b.flat_id").
		Joins("LEFT JOIN wings w ON w.id = f.wing_id").
		Where("b.status IN ?", []string{"ISSUED", "OVERDUE"}).
		Order("m.name ASC, b.due_date ASC").
		Scan(&bills).Error
	if err != nil {
		return nil, err
	}

	// Group by member
	memberMap := map[uuid.UUID]*DefaulterRow{}
	var order []uuid.UUID

	for _, b := range bills {
		row, exists := memberMap[b.MemberID]
		if !exists {
			row = &DefaulterRow{
				MemberID:   b.MemberID,
				MemberName: b.MemberName,
				FlatID:     b.FlatID,
				FlatNumber: b.FlatNumber,
				WingName:   b.WingName,
			}
			memberMap[b.MemberID] = row
			order = append(order, b.MemberID)
		}

		due := b.TotalAmount - b.AmountPaid
		if due <= 0 {
			continue
		}

		row.TotalBills++
		row.TotalAmount += b.TotalAmount
		row.AmountPaid += b.AmountPaid
		row.Outstanding += due
		row.InterestDue += b.InterestAmount

		// Track oldest due date
		if row.OldestDueDate == nil || b.DueDate.Before(*row.OldestDueDate) {
			t := b.DueDate
			row.OldestDueDate = &t
		}

		// Aging buckets
		daysOverdue := int(now.Sub(b.DueDate).Hours() / 24)
		if daysOverdue < 0 {
			daysOverdue = 0
		}
		switch {
		case daysOverdue <= 30:
			row.Bucket0to30 += due
		case daysOverdue <= 60:
			row.Bucket31to60 += due
		case daysOverdue <= 90:
			row.Bucket61to90 += due
		default:
			row.Bucket90Plus += due
		}
	}

	// Build ordered result
	var result []DefaulterRow
	for _, id := range order {
		row := memberMap[id]
		if row.Outstanding <= 0 {
			continue
		}
		if row.OldestDueDate != nil {
			row.DaysOverdue = int(now.Sub(*row.OldestDueDate).Hours() / 24)
			if row.DaysOverdue < 0 {
				row.DaysOverdue = 0
			}
		}
		// Per MCS Act, defaulter after 90 days
		row.IsDefaulter = row.DaysOverdue > 90
		result = append(result, *row)
	}

	return result, nil
}

// DefaulterSummary provides aggregated statistics.
type DefaulterSummary struct {
	TotalMembers       int     `json:"totalMembers"`
	DefaulterCount     int     `json:"defaulterCount"`
	TotalOutstanding   float64 `json:"totalOutstanding"`
	Bucket0to30Total   float64 `json:"bucket0to30Total"`
	Bucket31to60Total  float64 `json:"bucket31to60Total"`
	Bucket61to90Total  float64 `json:"bucket61to90Total"`
	Bucket90PlusTotal  float64 `json:"bucket90PlusTotal"`
}

// GetDefaulterSummary returns aggregated defaulter statistics.
func (r *DefaulterRepository) GetDefaulterSummary(actor *ActorContext) (*DefaulterSummary, error) {
	rows, err := r.GetDefaulterRegister(actor)
	if err != nil {
		return nil, err
	}

	summary := &DefaulterSummary{TotalMembers: len(rows)}
	for _, row := range rows {
		summary.TotalOutstanding += row.Outstanding
		summary.Bucket0to30Total += row.Bucket0to30
		summary.Bucket31to60Total += row.Bucket31to60
		summary.Bucket61to90Total += row.Bucket61to90
		summary.Bucket90PlusTotal += row.Bucket90Plus
		if row.IsDefaulter {
			summary.DefaulterCount++
		}
	}
	return summary, nil
}

// MemberStatement represents a chronological view of a member's transactions.
type MemberStatementRow struct {
	Date        time.Time `json:"date"`
	Description string    `json:"description"`
	DescriptionMr string  `json:"descriptionMr"`
	Debit       float64   `json:"debit"`  // charges/bills
	Credit      float64   `json:"credit"` // payments
	Balance     float64   `json:"balance"`
	RefType     string    `json:"refType"` // BILL, PAYMENT, INTEREST
	RefID       uuid.UUID `json:"refId"`
}

// GetMemberStatement returns a chronological statement of account for a member.
func (r *DefaulterRepository) GetMemberStatement(actor *ActorContext, memberID uuid.UUID) ([]MemberStatementRow, error) {
	// Members can see their own; admins can see any
	if !actor.IsAdmin() && actor.MemberID != memberID {
		return nil, ErrForbidden
	}

	// Get bills raised
	type billInfo struct {
		ID            uuid.UUID
		IssueDate     time.Time
		BillingPeriod string
		TotalAmount   float64
		AmountPaid    float64
		PaidAt        *time.Time
		InterestAmount float64
	}

	var bills []billInfo
	r.db.Table("soc_mitra_maintenance_bills").
		Select("id, issue_date, billing_period, total_amount, amount_paid, paid_at, interest_amount").
		Where("member_id = ?", memberID).
		Order("issue_date ASC").
		Scan(&bills)

	var rows []MemberStatementRow
	var balance float64

	for _, b := range bills {
		// Bill charge
		chargeAmount := b.TotalAmount
		balance += chargeAmount
		rows = append(rows, MemberStatementRow{
			Date:          b.IssueDate,
			Description:   "Maintenance Bill - " + b.BillingPeriod,
			DescriptionMr: "देखभाल बिल - " + b.BillingPeriod,
			Debit:         chargeAmount,
			Balance:       balance,
			RefType:       "BILL",
			RefID:         b.ID,
		})

		// Payment (if any)
		if b.AmountPaid > 0 {
			balance -= b.AmountPaid
			payDate := b.IssueDate
			if b.PaidAt != nil {
				payDate = *b.PaidAt
			}
			rows = append(rows, MemberStatementRow{
				Date:          payDate,
				Description:   "Payment Received - " + b.BillingPeriod,
				DescriptionMr: "भरणा प्राप्त - " + b.BillingPeriod,
				Credit:        b.AmountPaid,
				Balance:       balance,
				RefType:       "PAYMENT",
				RefID:         b.ID,
			})
		}
	}

	return rows, nil
}
