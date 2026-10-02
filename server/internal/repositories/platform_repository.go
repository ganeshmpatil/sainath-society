package repositories

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/models"
)

type PlatformRepository struct {
	db *gorm.DB
}

func NewPlatformRepository(db *gorm.DB) *PlatformRepository {
	return &PlatformRepository{db: db}
}

// ─── Platform Admin ─────────────────────────────────────────────────────────

func (r *PlatformRepository) FindAdminByEmail(email string) (*models.PlatformAdmin, error) {
	var admin models.PlatformAdmin
	if err := r.db.Where("email = ? AND is_active = ?", email, true).First(&admin).Error; err != nil {
		return nil, err
	}
	return &admin, nil
}

func (r *PlatformRepository) FindAdminByID(id uuid.UUID) (*models.PlatformAdmin, error) {
	var admin models.PlatformAdmin
	if err := r.db.First(&admin, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &admin, nil
}

// ─── Dashboard Stats ────────────────────────────────────────────────────────

type DashboardStats struct {
	TotalSocieties   int64 `json:"totalSocieties"`
	ActiveSocieties  int64 `json:"activeSocieties"`
	PendingRequests  int64 `json:"pendingRequests"`
	SuspendedCount   int64 `json:"suspendedSocieties"`
}

func (r *PlatformRepository) GetDashboardStats() (*DashboardStats, error) {
	var stats DashboardStats
	r.db.Model(&models.PlatformSociety{}).Count(&stats.TotalSocieties)
	r.db.Model(&models.PlatformSociety{}).Where("status = ?", models.SocietyActive).Count(&stats.ActiveSocieties)
	r.db.Model(&models.PlatformSociety{}).Where("status = ?", models.SocietySuspended).Count(&stats.SuspendedCount)
	r.db.Model(&models.PlatformOnboardingRequest{}).Where("status = ?", models.OnboardingPending).Count(&stats.PendingRequests)
	return &stats, nil
}

// ─── Onboarding Requests ────────────────────────────────────────────────────

func (r *PlatformRepository) CreateOnboardingRequest(req *models.PlatformOnboardingRequest) error {
	req.RequestNo = fmt.Sprintf("REQ-%d", time.Now().UnixNano()/1e6)
	return r.db.Create(req).Error
}

func (r *PlatformRepository) ListOnboardingRequests(status *models.OnboardingStatus) ([]models.PlatformOnboardingRequest, error) {
	q := r.db.Model(&models.PlatformOnboardingRequest{}).
		Preload("ReviewedBy").
		Order("created_at DESC")
	if status != nil {
		q = q.Where("status = ?", *status)
	}
	var rows []models.PlatformOnboardingRequest
	err := q.Find(&rows).Error
	return rows, err
}

func (r *PlatformRepository) GetOnboardingRequest(id uuid.UUID) (*models.PlatformOnboardingRequest, error) {
	var req models.PlatformOnboardingRequest
	if err := r.db.Preload("ReviewedBy").First(&req, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &req, nil
}

func (r *PlatformRepository) UpdateOnboardingRequest(req *models.PlatformOnboardingRequest) error {
	return r.db.Save(req).Error
}

// ─── Societies ──────────────────────────────────────────────────────────────

func (r *PlatformRepository) CreateSociety(soc *models.PlatformSociety) error {
	return r.db.Create(soc).Error
}

func (r *PlatformRepository) ListSocieties(status *models.SocietyStatus) ([]models.PlatformSociety, error) {
	q := r.db.Model(&models.PlatformSociety{}).
		Preload("ApprovedBy").
		Order("created_at DESC")
	if status != nil {
		q = q.Where("status = ?", *status)
	}
	var rows []models.PlatformSociety
	err := q.Find(&rows).Error
	return rows, err
}

func (r *PlatformRepository) GetSociety(id uuid.UUID) (*models.PlatformSociety, error) {
	var soc models.PlatformSociety
	if err := r.db.Preload("ApprovedBy").First(&soc, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &soc, nil
}

func (r *PlatformRepository) UpdateSociety(soc *models.PlatformSociety) error {
	return r.db.Save(soc).Error
}

// SocietyUsageStats returns usage numbers for a given society.
type SocietyUsageStats struct {
	TotalMembers     int64 `json:"totalMembers"`
	RegisteredUsers  int64 `json:"registeredUsers"`
	TotalFlats       int64 `json:"totalFlats"`
}

func (r *PlatformRepository) GetSocietyUsageStats(societyID uuid.UUID) (*SocietyUsageStats, error) {
	var stats SocietyUsageStats
	r.db.Model(&models.Member{}).Where("society_id = ? AND is_active = ?", societyID, true).Count(&stats.TotalMembers)
	r.db.Model(&models.Member{}).Where("society_id = ? AND is_registered = ?", societyID, true).Count(&stats.RegisteredUsers)
	r.db.Model(&models.Flat{}).Where("society_id = ?", societyID).Count(&stats.TotalFlats)
	return &stats, nil
}

// ─── Audit Log ──────────────────────────────────────────────────────────────

func (r *PlatformRepository) LogAction(adminID *uuid.UUID, action, entityType string, entityID *uuid.UUID, details, ip string) {
	entry := &models.PlatformAuditLog{
		AdminID:    adminID,
		Action:     action,
		EntityType: entityType,
		EntityID:   entityID,
		Details:    details,
		IPAddress:  ip,
	}
	r.db.Create(entry) // fire-and-forget
}

func (r *PlatformRepository) ListAuditLogs(limit int) ([]models.PlatformAuditLog, error) {
	if limit <= 0 {
		limit = 50
	}
	var logs []models.PlatformAuditLog
	err := r.db.Preload("Admin").Order("created_at DESC").Limit(limit).Find(&logs).Error
	return logs, err
}
