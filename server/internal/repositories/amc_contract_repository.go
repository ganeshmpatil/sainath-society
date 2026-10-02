package repositories

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type AMCContractRepository struct {
	db *gorm.DB
}

func NewAMCContractRepository(db *gorm.DB) *AMCContractRepository {
	return &AMCContractRepository{db: db}
}

func (r *AMCContractRepository) List(actor *ActorContext) ([]models.AMCContract, error) {
	var rows []models.AMCContract
	err := r.db.Preload("Vendor").Order("end_date ASC").Find(&rows).Error
	return rows, err
}

func (r *AMCContractRepository) GetByID(id uuid.UUID) (*models.AMCContract, error) {
	var c models.AMCContract
	if err := r.db.Preload("Vendor").First(&c, "id = ?", id).Error; err != nil {
		return nil, ErrNotFound
	}
	return &c, nil
}

func (r *AMCContractRepository) Create(actor *ActorContext, c *models.AMCContract) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	c.CreatedByID = actor.MemberID
	return r.db.Create(c).Error
}

func (r *AMCContractRepository) Update(actor *ActorContext, id uuid.UUID, updates map[string]interface{}) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Model(&models.AMCContract{}).Where("id = ?", id).Updates(updates)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

func (r *AMCContractRepository) Delete(actor *ActorContext, id uuid.UUID) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	result := r.db.Delete(&models.AMCContract{}, "id = ?", id)
	if result.RowsAffected == 0 {
		return ErrNotFound
	}
	return result.Error
}

// GetExpiringSoon returns contracts expiring within the specified number of days.
func (r *AMCContractRepository) GetExpiringSoon(days int) ([]models.AMCContract, error) {
	now := time.Now()
	deadline := now.AddDate(0, 0, days)
	var rows []models.AMCContract
	err := r.db.Where("status = ? AND end_date > ? AND end_date <= ?",
		models.ContractActive, now, deadline).
		Preload("Vendor").
		Order("end_date ASC").
		Find(&rows).Error
	return rows, err
}

// GetExpired returns contracts past their end date that are still marked active.
func (r *AMCContractRepository) GetExpired() ([]models.AMCContract, error) {
	var rows []models.AMCContract
	err := r.db.Where("status = ? AND end_date < ?", models.ContractActive, time.Now()).
		Preload("Vendor").Find(&rows).Error
	return rows, err
}

// Summary returns counts of active, expiring-soon, and expired contracts.
func (r *AMCContractRepository) Summary() (active, expiringSoon, expired int64, totalAmount float64, err error) {
	now := time.Now()
	soon := now.AddDate(0, 0, 30)

	r.db.Model(&models.AMCContract{}).Where("status = ? AND end_date > ?", models.ContractActive, soon).Count(&active)
	r.db.Model(&models.AMCContract{}).Where("status = ? AND end_date > ? AND end_date <= ?", models.ContractActive, now, soon).Count(&expiringSoon)
	r.db.Model(&models.AMCContract{}).Where("status = ? AND end_date < ?", models.ContractActive, now).Count(&expired)
	r.db.Model(&models.AMCContract{}).Where("status = ?", models.ContractActive).
		Select("COALESCE(SUM(contract_amount), 0)").Row().Scan(&totalAmount)
	return
}

// ─── Service Logs ──────────────────────────────────────────────

func (r *AMCContractRepository) LogService(actor *ActorContext, log *models.ServiceLog) error {
	if !actor.IsAdmin() {
		return ErrForbidden
	}
	log.LoggedByID = actor.MemberID
	return r.db.Create(log).Error
}

func (r *AMCContractRepository) ListServiceLogs(contractID uuid.UUID) ([]models.ServiceLog, error) {
	var rows []models.ServiceLog
	err := r.db.Where("contract_id = ?", contractID).Order("service_date DESC").Find(&rows).Error
	return rows, err
}
