package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type HallBookingStatus string

const (
	HallBookingPending   HallBookingStatus = "PENDING"
	HallBookingApproved  HallBookingStatus = "APPROVED"
	HallBookingRejected  HallBookingStatus = "REJECTED"
	HallBookingCompleted HallBookingStatus = "COMPLETED"
	HallBookingCancelled HallBookingStatus = "CANCELLED"
)

type HallPaymentStatus string

const (
	HallPaymentPending HallPaymentStatus = "PENDING"
	HallPaymentPaid    HallPaymentStatus = "PAID"
	HallPaymentRefunded HallPaymentStatus = "REFUNDED"
)

// HallBooking represents a community hall reservation by a member.
// Row-level access: BookedByMemberID + ADMIN.
type HallBooking struct {
	ID              uuid.UUID         `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	BookedByMemberID uuid.UUID        `gorm:"type:uuid;not null;index" json:"bookedByMemberId"`
	FlatID          *uuid.UUID        `gorm:"type:uuid;index" json:"flatId,omitempty"`

	Purpose         string            `gorm:"type:varchar(200);not null" json:"purpose"`
	PurposeMr       string            `gorm:"type:varchar(200)" json:"purposeMr,omitempty"`
	EventType       string            `gorm:"type:varchar(50)" json:"eventType,omitempty"` // birthday, wedding, puja, etc
	ExpectedGuests  int               `json:"expectedGuests,omitempty"`

	StartTime       time.Time         `gorm:"not null;index" json:"startTime"`
	EndTime         time.Time         `gorm:"not null;index" json:"endTime"`

	Status          HallBookingStatus `gorm:"type:varchar(20);not null;default:'PENDING'" json:"status"`
	PaymentStatus   HallPaymentStatus `gorm:"type:varchar(20);not null;default:'PENDING'" json:"paymentStatus"`
	BookingCharge   float64           `gorm:"type:decimal(10,2);default:0" json:"bookingCharge"`
	Deposit         float64           `gorm:"type:decimal(10,2);default:0" json:"deposit"`

	ApprovedByID    *uuid.UUID        `gorm:"type:uuid" json:"approvedById,omitempty"`
	ApprovedAt      *time.Time        `json:"approvedAt,omitempty"`
	RejectReason    string            `gorm:"type:varchar(500)" json:"rejectReason,omitempty"`

	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	BookedBy *Member `gorm:"foreignKey:BookedByMemberID" json:"bookedBy,omitempty"`
	Flat     *Flat   `gorm:"foreignKey:FlatID" json:"flat,omitempty"`
}

func (h *HallBooking) BeforeCreate(tx *gorm.DB) error {
	if h.ID == uuid.Nil {
		h.ID = uuid.New()
	}
	return nil
}

func (HallBooking) TableName() string { return "soc_mitra_hall_bookings" }
