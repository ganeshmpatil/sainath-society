package repositories

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

type StaffRepository struct {
	db *gorm.DB
}

func NewStaffRepository(db *gorm.DB) *StaffRepository {
	return &StaffRepository{db: db}
}

// List returns all staff (active by default).
func (r *StaffRepository) List(actor *ActorContext, includeInactive bool) ([]models.Staff, error) {
	q := r.db.Order("name ASC")
	if !includeInactive {
		q = q.Where("is_active = ?", true)
	}
	var rows []models.Staff
	return rows, q.Find(&rows).Error
}

// GetByID returns a single staff member.
func (r *StaffRepository) GetByID(id uuid.UUID) (*models.Staff, error) {
	var s models.Staff
	if err := r.db.First(&s, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &s, nil
}

// Create adds a new staff member.
func (r *StaffRepository) Create(actor *ActorContext, s *models.Staff) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	s.CreatedByID = actor.MemberID
	return r.db.Create(s).Error
}

// Update modifies a staff member.
func (r *StaffRepository) Update(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.Staff{}).Where("id = ?", id).Updates(updates)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// MarkAttendance records daily attendance for a staff member.
func (r *StaffRepository) MarkAttendance(actor *ActorContext, att *models.StaffAttendance) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	att.MarkedByID = actor.MemberID
	// Upsert: if attendance already exists for this staff+date, update it
	var existing models.StaffAttendance
	err := r.db.Where("staff_id = ? AND date = ?", att.StaffID, att.Date).First(&existing).Error
	if err == nil {
		return r.db.Model(&existing).Updates(map[string]interface{}{
			"status":   att.Status,
			"in_time":  att.InTime,
			"out_time": att.OutTime,
			"notes":    att.Notes,
		}).Error
	}
	return r.db.Create(att).Error
}

// GetAttendance returns attendance records for a staff member in a month.
func (r *StaffRepository) GetAttendance(staffID uuid.UUID, month string) ([]models.StaffAttendance, error) {
	// month = "2026-09"
	startDate := month + "-01"
	var rows []models.StaffAttendance
	err := r.db.Where("staff_id = ? AND date >= ? AND date < (?::date + interval '1 month')",
		staffID, startDate, startDate).
		Order("date ASC").Find(&rows).Error
	return rows, err
}

// AttendanceSummary returns present/absent/half-day counts for a staff member in a month.
func (r *StaffRepository) AttendanceSummary(staffID uuid.UUID, month string) (present, absent, halfDay, leave int, err error) {
	records, err := r.GetAttendance(staffID, month)
	if err != nil {
		return
	}
	for _, a := range records {
		switch a.Status {
		case "PRESENT":
			present++
		case "ABSENT":
			absent++
		case "HALF_DAY":
			halfDay++
		case "LEAVE":
			leave++
		}
	}
	return
}

// RecordSalaryPayment creates a salary payment record.
func (r *StaffRepository) RecordSalaryPayment(actor *ActorContext, payment *models.StaffSalaryPayment) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	payment.PaidByID = actor.MemberID
	return r.db.Create(payment).Error
}

// ListSalaryPayments returns salary payments for a staff member.
func (r *StaffRepository) ListSalaryPayments(staffID uuid.UUID) ([]models.StaffSalaryPayment, error) {
	var rows []models.StaffSalaryPayment
	err := r.db.Where("staff_id = ?", staffID).Order("month DESC").Find(&rows).Error
	return rows, err
}

// MonthlySalarySummary returns total salary expense for a given month.
func (r *StaffRepository) MonthlySalarySummary(month string) (totalGross, totalNet float64, count int, err error) {
	var result struct {
		TotalGross float64
		TotalNet   float64
		Count      int
	}
	err = r.db.Model(&models.StaffSalaryPayment{}).
		Select("COALESCE(SUM(gross_amount),0) as total_gross, COALESCE(SUM(net_amount),0) as total_net, COUNT(*) as count").
		Where("month = ?", month).Scan(&result).Error
	return result.TotalGross, result.TotalNet, result.Count, err
}

// TodayAttendance returns today's attendance for all active staff.
func (r *StaffRepository) TodayAttendance() ([]models.StaffAttendance, error) {
	today := time.Now().Format("2006-01-02")
	var rows []models.StaffAttendance
	err := r.db.Where("date = ?", today).Preload("Staff").Find(&rows).Error
	return rows, err
}

// CalculateSalary computes salary based on attendance for a month.
func (r *StaffRepository) CalculateSalary(staffID uuid.UUID, month string) (*models.StaffSalaryPayment, error) {
	staff, err := r.GetByID(staffID)
	if err != nil {
		return nil, err
	}

	present, _, halfDay, _, err := r.AttendanceSummary(staffID, month)
	if err != nil {
		return nil, err
	}

	// Parse month to get days in month
	t, _ := time.Parse("2006-01", month)
	daysInMonth := time.Date(t.Year(), t.Month()+1, 0, 0, 0, 0, 0, time.UTC).Day()

	effectiveDays := float64(present) + float64(halfDay)*0.5
	perDay := staff.MonthlySalary / float64(daysInMonth)
	gross := perDay * effectiveDays

	return &models.StaffSalaryPayment{
		StaffID:     staffID,
		Month:       month,
		WorkingDays: daysInMonth,
		PresentDays: present,
		GrossAmount: gross,
		NetAmount:   gross, // deductions applied separately
		PaidDate:    time.Now(),
	}, nil
}

// StaffExpenseSummary returns total staff salary for a financial year.
func (r *StaffRepository) StaffExpenseSummary(fyStart, fyEnd string) (float64, error) {
	var total float64
	err := r.db.Model(&models.StaffSalaryPayment{}).
		Select("COALESCE(SUM(net_amount),0)").
		Where("month >= ? AND month <= ?", fyStart, fyEnd).
		Row().Scan(&total)
	return total, err
}

// BulkMarkAttendance marks attendance for multiple staff at once.
func (r *StaffRepository) BulkMarkAttendance(actor *ActorContext, date time.Time, records []models.StaffAttendance) (int, error) {
	if !actor.IsAdmin() {
		return 0, ErrForbidden
	}
	marked := 0
	for i := range records {
		records[i].Date = date
		records[i].MarkedByID = actor.MemberID
		var existing models.StaffAttendance
		if err := r.db.Where("staff_id = ? AND date = ?", records[i].StaffID, date).First(&existing).Error; err == nil {
			r.db.Model(&existing).Updates(map[string]interface{}{
				"status":  records[i].Status,
				"in_time": records[i].InTime,
				"out_time": records[i].OutTime,
			})
		} else {
			r.db.Create(&records[i])
		}
		marked++
	}
	return marked, nil
}

func init() {
	_ = fmt.Sprintf // keep fmt import
}
