package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type NotificationChannel string

const (
	ChannelWhatsApp NotificationChannel = "WHATSAPP"
	ChannelSMS      NotificationChannel = "SMS"
	ChannelEmail    NotificationChannel = "EMAIL"
	ChannelInApp    NotificationChannel = "IN_APP"
	ChannelPush     NotificationChannel = "PUSH"
)

type NotificationStatus string

const (
	NotifPending   NotificationStatus = "PENDING"
	NotifSent      NotificationStatus = "SENT"
	NotifDelivered NotificationStatus = "DELIVERED"
	NotifRead      NotificationStatus = "READ"
	NotifFailed    NotificationStatus = "FAILED"
)

// Notification is an outbound alert targeted at a specific member
// (used for WhatsApp, SMS, Email, push, in-app).
type Notification struct {
	ID          uuid.UUID           `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	RecipientID uuid.UUID           `gorm:"type:uuid;not null;index" json:"recipientId"`
	Channel     NotificationChannel `gorm:"type:varchar(20);not null" json:"channel"`
	Status      NotificationStatus  `gorm:"type:varchar(20);not null;default:'PENDING'" json:"status"`

	Subject     string `gorm:"type:varchar(200)" json:"subject,omitempty"`
	Body        string `gorm:"type:text;not null" json:"body"`
	BodyMr      string `gorm:"type:text" json:"bodyMr,omitempty"`
	Language    string `gorm:"type:varchar(5);default:'en'" json:"language"` // en | mr

	// Link to business event
	EventType   string     `gorm:"type:varchar(50)" json:"eventType,omitempty"` // e.g. "TASK_REMINDER", "GRIEVANCE_UPDATE"
	ResourceType string    `gorm:"type:varchar(50)" json:"resourceType,omitempty"`
	ResourceID  *uuid.UUID `gorm:"type:uuid" json:"resourceId,omitempty"`

	// Delivery tracking
	ProviderRef    string     `gorm:"type:varchar(200)" json:"providerRef,omitempty"` // WhatsApp msgId / SMS ref
	SentAt         *time.Time `json:"sentAt,omitempty"`
	DeliveredAt    *time.Time `json:"deliveredAt,omitempty"`
	ReadAt         *time.Time `json:"readAt,omitempty"`
	FailureReason  string     `gorm:"type:varchar(500)" json:"failureReason,omitempty"`
	RetryCount     int        `gorm:"default:0" json:"retryCount"`

	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Recipient *Member `gorm:"foreignKey:RecipientID" json:"recipient,omitempty"`
}

func (n *Notification) BeforeCreate(tx *gorm.DB) error {
	if n.ID == uuid.Nil {
		n.ID = uuid.New()
	}
	return nil
}

func (Notification) TableName() string { return "soc_mitra_notifications" }

// NotificationTemplate holds reusable templated message bodies (EN + MR).
type NotificationTemplate struct {
	ID          uuid.UUID           `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Code        string              `gorm:"type:varchar(50);uniqueIndex;not null" json:"code"` // e.g. "TASK_REMINDER"
	Channel     NotificationChannel `gorm:"type:varchar(20);not null" json:"channel"`
	SubjectEn   string              `gorm:"type:varchar(200)" json:"subjectEn,omitempty"`
	SubjectMr   string              `gorm:"type:varchar(200)" json:"subjectMr,omitempty"`
	BodyEn      string              `gorm:"type:text;not null" json:"bodyEn"`
	BodyMr      string              `gorm:"type:text" json:"bodyMr,omitempty"`
	Variables   string              `gorm:"type:varchar(500)" json:"variables,omitempty"` // CSV of {{name}},{{amount}}...
	IsActive    bool                `gorm:"default:true" json:"isActive"`
	CreatedAt   time.Time           `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time           `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (NotificationTemplate) TableName() string { return "soc_mitra_notification_templates" }
