package models

import (
	"time"
)

type DemoRequest struct {
	ID            uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	ContactPerson string    `gorm:"type:varchar(255);not null" json:"contactPerson"`
	Phone         string    `gorm:"type:varchar(20);not null" json:"phone"`
	Email         string    `gorm:"type:varchar(255)" json:"email,omitempty"`
	SocietyName   string    `gorm:"type:varchar(255)" json:"societyName,omitempty"`
	City          string    `gorm:"type:varchar(100)" json:"city,omitempty"`
	TotalFlats    string    `gorm:"type:varchar(20)" json:"totalFlats,omitempty"`
	Role          string    `gorm:"type:varchar(50)" json:"role,omitempty"`
	Message       string    `gorm:"type:text" json:"message,omitempty"`
	Status        string    `gorm:"type:varchar(20);default:'pending'" json:"status"`
	CreatedAt     time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (DemoRequest) TableName() string { return "marketing_demo_requests" }

type Inquiry struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Name        string    `gorm:"type:varchar(255);not null" json:"name"`
	Phone       string    `gorm:"type:varchar(20);not null" json:"phone"`
	Email       string    `gorm:"type:varchar(255)" json:"email,omitempty"`
	SocietyName string    `gorm:"type:varchar(255)" json:"societyName,omitempty"`
	Message     string    `gorm:"type:text" json:"message,omitempty"`
	Status      string    `gorm:"type:varchar(20);default:'new'" json:"status"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
}

func (Inquiry) TableName() string { return "marketing_inquiries" }
