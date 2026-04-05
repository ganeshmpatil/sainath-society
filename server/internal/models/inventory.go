package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ItemCondition string

const (
	ConditionNew       ItemCondition = "NEW"
	ConditionGood      ItemCondition = "GOOD"
	ConditionFair      ItemCondition = "FAIR"
	ConditionPoor      ItemCondition = "POOR"
	ConditionNeedsRepair ItemCondition = "NEEDS_REPAIR"
	ConditionScrapped  ItemCondition = "SCRAPPED"
)

// InventoryItem represents a society asset (chairs, tables, gym equipment,
// gardening tools etc). All members can view the list; only admins mutate it.
type InventoryItem struct {
	ID          uuid.UUID     `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Name        string        `gorm:"type:varchar(200);not null" json:"name"`
	NameMr      string        `gorm:"type:varchar(200)" json:"nameMr,omitempty"`
	Category    string        `gorm:"type:varchar(50);not null" json:"category"`
	Description string        `gorm:"type:text" json:"description,omitempty"`
	DescriptionMr string      `gorm:"type:text" json:"descriptionMr,omitempty"`

	Quantity    int           `gorm:"default:1" json:"quantity"`
	UnitPrice   float64       `gorm:"type:decimal(10,2)" json:"unitPrice"`
	TotalValue  float64       `gorm:"type:decimal(12,2)" json:"totalValue"`

	Condition   ItemCondition `gorm:"type:varchar(20);not null;default:'GOOD'" json:"condition"`
	Location    string        `gorm:"type:varchar(200)" json:"location,omitempty"`
	SerialNo    string        `gorm:"type:varchar(100)" json:"serialNo,omitempty"`

	PurchaseDate    *time.Time `json:"purchaseDate,omitempty"`
	WarrantyExpiry  *time.Time `json:"warrantyExpiry,omitempty"`
	LastAuditedAt   *time.Time `json:"lastAuditedAt,omitempty"`

	AddedByID uuid.UUID `gorm:"type:uuid;not null" json:"addedById"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updatedAt"`
}

func (i *InventoryItem) BeforeCreate(tx *gorm.DB) error {
	if i.ID == uuid.Nil {
		i.ID = uuid.New()
	}
	return nil
}

func (InventoryItem) TableName() string { return "soc_mitra_inventory_items" }
