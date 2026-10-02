package repositories

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type AuditChecklistRepository struct {
	db *gorm.DB
}

func NewAuditChecklistRepository(db *gorm.DB) *AuditChecklistRepository {
	return &AuditChecklistRepository{db: db}
}

func (r *AuditChecklistRepository) List() ([]models.AuditChecklist, error) {
	var rows []models.AuditChecklist
	err := r.db.Order("created_at DESC").Find(&rows).Error
	return rows, err
}

func (r *AuditChecklistRepository) GetByID(id uuid.UUID) (*models.AuditChecklist, error) {
	var row models.AuditChecklist
	err := r.db.Preload("Items", func(db *gorm.DB) *gorm.DB {
		return db.Order("sort_order ASC, created_at ASC")
	}).First(&row, "id = ?", id).Error
	return &row, err
}

func (r *AuditChecklistRepository) Create(actor *ActorContext, c *models.AuditChecklist) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	c.CreatedByID = actor.UserID
	return r.db.Create(c).Error
}

func (r *AuditChecklistRepository) Update(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.AuditChecklist{}).Where("id = ?", id).Updates(updates).Error
}

func (r *AuditChecklistRepository) AddItem(actor *ActorContext, item *models.AuditChecklistItem) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Create(item).Error
}

func (r *AuditChecklistRepository) ToggleItem(actor *ActorContext, itemID uuid.UUID, completed bool) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	updates := map[string]interface{}{
		"is_completed": completed,
	}
	if completed {
		now := time.Now()
		updates["completed_by"] = actor.UserID
		updates["completed_at"] = now
	} else {
		updates["completed_by"] = nil
		updates["completed_at"] = nil
	}
	return r.db.Model(&models.AuditChecklistItem{}).Where("id = ?", itemID).Updates(updates).Error
}

func (r *AuditChecklistRepository) UpdateItemRemarks(actor *ActorContext, itemID uuid.UUID, remarks string) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Model(&models.AuditChecklistItem{}).Where("id = ?", itemID).Update("remarks", remarks).Error
}

func (r *AuditChecklistRepository) DeleteItem(actor *ActorContext, itemID uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	return r.db.Delete(&models.AuditChecklistItem{}, "id = ?", itemID).Error
}

func (r *AuditChecklistRepository) Progress(checklistID uuid.UUID) (map[string]interface{}, error) {
	var total int64
	var completed int64
	r.db.Model(&models.AuditChecklistItem{}).Where("checklist_id = ?", checklistID).Count(&total)
	r.db.Model(&models.AuditChecklistItem{}).Where("checklist_id = ? AND is_completed = ?", checklistID, true).Count(&completed)
	pct := 0.0
	if total > 0 {
		pct = float64(completed) / float64(total) * 100
	}
	return map[string]interface{}{
		"total":     total,
		"completed": completed,
		"pending":   total - completed,
		"percent":   fmt.Sprintf("%.0f", pct),
	}, nil
}

// CreateWithDefaults creates a checklist pre-populated with standard MCS Act audit items.
func (r *AuditChecklistRepository) CreateWithDefaults(actor *ActorContext, c *models.AuditChecklist) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	c.CreatedByID = actor.UserID
	if err := r.db.Create(c).Error; err != nil {
		return err
	}
	defaults := []models.AuditChecklistItem{
		{ChecklistID: c.ID, Category: "FINANCIAL", Title: "Income & Expenditure Statement prepared", TitleMr: "उत्पन्न आणि खर्च विवरण तयार", SortOrder: 1},
		{ChecklistID: c.ID, Category: "FINANCIAL", Title: "Balance Sheet prepared (Schedule IX format)", TitleMr: "ताळेबंद तयार (अनुसूची IX)", SortOrder: 2},
		{ChecklistID: c.ID, Category: "FINANCIAL", Title: "Trial Balance verified", TitleMr: "ट्रायल बॅलन्स तपासला", SortOrder: 3},
		{ChecklistID: c.ID, Category: "FINANCIAL", Title: "Receipt & Payment Account prepared", TitleMr: "जमा आणि देय खाते तयार", SortOrder: 4},
		{ChecklistID: c.ID, Category: "FINANCIAL", Title: "Bank reconciliation completed", TitleMr: "बँक जुळणी पूर्ण", SortOrder: 5},
		{ChecklistID: c.ID, Category: "FINANCIAL", Title: "Fund-wise accounting (Sinking, Repair, Reserve)", TitleMr: "निधीनुसार हिशोब (सिंकिंग, दुरुस्ती, राखीव)", SortOrder: 6},
		{ChecklistID: c.ID, Category: "FINANCIAL", Title: "TDS returns filed and certificates obtained", TitleMr: "TDS रिटर्न दाखल आणि प्रमाणपत्रे मिळवली", SortOrder: 7},
		{ChecklistID: c.ID, Category: "REGISTERS", Title: "Member Register updated", TitleMr: "सदस्य नोंदणी अद्ययावत", SortOrder: 10},
		{ChecklistID: c.ID, Category: "REGISTERS", Title: "Share Register maintained", TitleMr: "शेअर नोंदणी अद्ययावत", SortOrder: 11},
		{ChecklistID: c.ID, Category: "REGISTERS", Title: "Meeting minutes register complete", TitleMr: "बैठक इतिवृत्त नोंदणी पूर्ण", SortOrder: 12},
		{ChecklistID: c.ID, Category: "REGISTERS", Title: "Property Register maintained", TitleMr: "मालमत्ता नोंदणी अद्ययावत", SortOrder: 13},
		{ChecklistID: c.ID, Category: "COMPLIANCE", Title: "AGM conducted within statutory deadline", TitleMr: "वैधानिक मुदतीत सर्वसाधारण सभा घेतली", SortOrder: 20},
		{ChecklistID: c.ID, Category: "COMPLIANCE", Title: "Audit report of previous year filed", TitleMr: "मागील वर्षाचा लेखापरीक्षा अहवाल दाखल", SortOrder: 21},
		{ChecklistID: c.ID, Category: "COMPLIANCE", Title: "Society registration renewed (if due)", TitleMr: "सोसायटी नोंदणी नूतनीकरण (आवश्यक असल्यास)", SortOrder: 22},
		{ChecklistID: c.ID, Category: "COMPLIANCE", Title: "GST returns filed (if applicable)", TitleMr: "GST रिटर्न दाखल (लागू असल्यास)", SortOrder: 23},
		{ChecklistID: c.ID, Category: "DOCUMENTS", Title: "All vendor contracts & agreements available", TitleMr: "सर्व विक्रेता करार उपलब्ध", SortOrder: 30},
		{ChecklistID: c.ID, Category: "DOCUMENTS", Title: "Insurance policies current", TitleMr: "विमा पॉलिसी चालू", SortOrder: 31},
		{ChecklistID: c.ID, Category: "DOCUMENTS", Title: "NOC and transfer documents filed", TitleMr: "NOC आणि हस्तांतरण कागदपत्रे दाखल", SortOrder: 32},
		{ChecklistID: c.ID, Category: "DOCUMENTS", Title: "Bank passbook / statement reconciled", TitleMr: "बँक पासबुक / स्टेटमेंट जुळवले", SortOrder: 33},
	}
	return r.db.Create(&defaults).Error
}
