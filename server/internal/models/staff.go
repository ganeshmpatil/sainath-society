package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// StaffRole categorizes society employees.
type StaffRole string

const (
	StaffSecurity   StaffRole = "SECURITY"
	StaffSweeper    StaffRole = "SWEEPER"
	StaffPlumber    StaffRole = "PLUMBER"
	StaffElectrician StaffRole = "ELECTRICIAN"
	StaffGardener   StaffRole = "GARDENER"
	StaffClerk      StaffRole = "CLERK"
	StaffManager    StaffRole = "MANAGER"
	StaffOther      StaffRole = "OTHER"
)

// StaffType distinguishes employment type.
type StaffType string

const (
	StaffPermanent StaffType = "PERMANENT"
	StaffContract  StaffType = "CONTRACT"
)

// Staff represents a society-employed worker.
type Staff struct {
	TenantScope
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name         string    `gorm:"type:varchar(100);not null" json:"name"`
	NameMr       string    `gorm:"type:varchar(100)" json:"nameMr,omitempty"`
	Mobile       string    `gorm:"type:varchar(15);not null" json:"mobile"`
	AltMobile    string    `gorm:"type:varchar(15)" json:"altMobile,omitempty"`
	Role         StaffRole `gorm:"type:varchar(20);not null" json:"role"`
	StaffType    StaffType `gorm:"type:varchar(20);not null;default:'PERMANENT'" json:"staffType"`
	AadhaarNo    string    `gorm:"type:varchar(12)" json:"aadhaarNo,omitempty"`
	Address      string    `gorm:"type:text" json:"address,omitempty"`
	MonthlySalary float64  `gorm:"type:decimal(10,2);not null" json:"monthlySalary"`
	JoiningDate  time.Time `gorm:"not null" json:"joiningDate"`
	LeavingDate  *time.Time `json:"leavingDate,omitempty"`
	ShiftStart   string    `gorm:"type:varchar(5)" json:"shiftStart,omitempty"` // HH:MM
	ShiftEnd     string    `gorm:"type:varchar(5)" json:"shiftEnd,omitempty"`   // HH:MM
	BankAccount  string    `gorm:"type:varchar(20)" json:"bankAccount,omitempty"`
	BankIFSC     string    `gorm:"type:varchar(15)" json:"bankIfsc,omitempty"`
	IsActive     bool      `gorm:"default:true" json:"isActive"`
	Notes        string    `gorm:"type:text" json:"notes,omitempty"`
	CreatedByID  uuid.UUID `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt    time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt    time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (s *Staff) BeforeCreate(tx *gorm.DB) error {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	return nil
}

func (Staff) TableName() string { return "soc_mitra_staff" }

// StaffAttendance records daily attendance.
type StaffAttendance struct {
	TenantScope
	ID        uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	StaffID   uuid.UUID `gorm:"type:uuid;not null;index:idx_staff_date,unique" json:"staffId"`
	Date      time.Time `gorm:"type:date;not null;index:idx_staff_date,unique" json:"date"`
	Status    string    `gorm:"type:varchar(10);not null" json:"status"` // PRESENT, ABSENT, HALF_DAY, LEAVE
	InTime    string    `gorm:"type:varchar(5)" json:"inTime,omitempty"`
	OutTime   string    `gorm:"type:varchar(5)" json:"outTime,omitempty"`
	Notes     string    `gorm:"type:varchar(200)" json:"notes,omitempty"`
	MarkedByID uuid.UUID `gorm:"type:uuid;not null" json:"markedById"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`

	Staff *Staff `gorm:"foreignKey:StaffID" json:"staff,omitempty"`
}

func (a *StaffAttendance) BeforeCreate(tx *gorm.DB) error {
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	return nil
}

func (StaffAttendance) TableName() string { return "soc_mitra_staff_attendance" }

// StaffSalaryPayment records monthly salary disbursement.
type StaffSalaryPayment struct {
	TenantScope
	ID          uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	StaffID     uuid.UUID `gorm:"type:uuid;not null;index" json:"staffId"`
	Month       string    `gorm:"type:varchar(7);not null" json:"month"` // 2026-09
	WorkingDays int       `gorm:"not null" json:"workingDays"`
	PresentDays int       `gorm:"not null" json:"presentDays"`
	GrossAmount float64   `gorm:"type:decimal(10,2);not null" json:"grossAmount"`
	Deductions  float64   `gorm:"type:decimal(10,2);default:0" json:"deductions"`
	NetAmount   float64   `gorm:"type:decimal(10,2);not null" json:"netAmount"`
	PaymentMode string    `gorm:"type:varchar(20)" json:"paymentMode,omitempty"` // CASH, BANK, UPI
	PaidDate    time.Time `gorm:"not null" json:"paidDate"`
	PaidByID    uuid.UUID `gorm:"type:uuid;not null" json:"paidById"`
	Notes       string    `gorm:"type:text" json:"notes,omitempty"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`

	Staff *Staff `gorm:"foreignKey:StaffID" json:"staff,omitempty"`
}

func (p *StaffSalaryPayment) BeforeCreate(tx *gorm.DB) error {
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	return nil
}

func (StaffSalaryPayment) TableName() string { return "soc_mitra_staff_salary_payments" }
