package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// JournalEntry represents a double-entry accounting transaction.
// Every journal entry must have balanced debit and credit lines.
type JournalEntry struct {
	ID          uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	EntryNo     string    `gorm:"type:varchar(30);uniqueIndex;not null" json:"entryNo"`
	EntryDate   time.Time `gorm:"not null" json:"entryDate"`
	Narration   string    `gorm:"type:varchar(500);not null" json:"narration"`
	NarrationMr string    `gorm:"type:varchar(500)" json:"narrationMr"`

	// Reference to source document (bill, payment, etc.)
	RefType string     `gorm:"type:varchar(30)" json:"refType,omitempty"` // BILL, PAYMENT, EXPENSE, TRANSFER, MANUAL
	RefID   *uuid.UUID `gorm:"type:uuid;index" json:"refId,omitempty"`

	TotalAmount float64 `gorm:"type:decimal(12,2);not null" json:"totalAmount"`
	IsAutomatic bool    `gorm:"not null;default:false" json:"isAutomatic"` // system-generated vs manual

	CreatedByID uuid.UUID `gorm:"type:uuid;not null" json:"createdById"`
	CreatedAt   time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt   time.Time `gorm:"autoUpdateTime" json:"updatedAt"`

	Lines []JournalLine `gorm:"foreignKey:JournalEntryID" json:"lines,omitempty"`
}

func (j *JournalEntry) BeforeCreate(tx *gorm.DB) error {
	if j.ID == uuid.Nil {
		j.ID = uuid.New()
	}
	return nil
}

func (JournalEntry) TableName() string { return "soc_mitra_journal_entries" }

// JournalLine is a single debit or credit line in a journal entry.
type JournalLine struct {
	ID             uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	JournalEntryID uuid.UUID `gorm:"type:uuid;not null;index" json:"journalEntryId"`
	AccountHeadID  uuid.UUID `gorm:"type:uuid;not null;index" json:"accountHeadId"`
	DebitAmount    float64   `gorm:"type:decimal(12,2);not null;default:0" json:"debitAmount"`
	CreditAmount   float64   `gorm:"type:decimal(12,2);not null;default:0" json:"creditAmount"`
	Narration      string    `gorm:"type:varchar(300)" json:"narration,omitempty"`
	CreatedAt      time.Time `gorm:"autoCreateTime" json:"createdAt"`

	AccountHead *AccountHead `gorm:"foreignKey:AccountHeadID" json:"accountHead,omitempty"`
}

func (l *JournalLine) BeforeCreate(tx *gorm.DB) error {
	if l.ID == uuid.Nil {
		l.ID = uuid.New()
	}
	return nil
}

func (JournalLine) TableName() string { return "soc_mitra_journal_lines" }
