package services

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
	"sainath-society/pkg/jwt"
)

var (
	ErrDuplicateRegNumber  = errors.New("a society with this registration number already exists")
	ErrRequestNotPending   = errors.New("request is not in PENDING or INFO_REQUESTED status")
	ErrSocietyNotFound     = errors.New("society not found")
	ErrInvalidRegNumber    = errors.New("registration number format is invalid")
)

// regNumberPattern matches Maharashtra co-op housing society registration numbers.
// Examples: BOM/HSG/1234, PUN/HSG/5678/2019, THANE/HSG/123
var regNumberPattern = regexp.MustCompile(`^[A-Z]+/HSG/\d+(/\d{4})?$`)

type PlatformService struct {
	repo       *repositories.PlatformRepository
	jwtManager *jwt.Manager
}

func NewPlatformService(repo *repositories.PlatformRepository, jwtManager *jwt.Manager) *PlatformService {
	return &PlatformService{repo: repo, jwtManager: jwtManager}
}

// ─── Platform Admin Auth ────────────────────────────────────────────────────

func (s *PlatformService) LoginAdmin(email, password string) (string, *models.PlatformAdmin, error) {
	admin, err := s.repo.FindAdminByEmail(email)
	if err != nil {
		return "", nil, ErrInvalidCredentials
	}
	if err := bcrypt.CompareHashAndPassword([]byte(admin.PasswordHash), []byte(password)); err != nil {
		return "", nil, ErrInvalidCredentials
	}
	// Generate a simple access token (platform admin tokens have no society context)
	tokenPair, err := s.jwtManager.GenerateTokenPair(
		admin.ID, admin.Email, "PLATFORM_ADMIN", "", "", "", nil,
	)
	if err != nil {
		return "", nil, err
	}
	return tokenPair.AccessToken, admin, nil
}

// ─── Dashboard ──────────────────────────────────────────────────────────────

func (s *PlatformService) GetDashboardStats() (*repositories.DashboardStats, error) {
	return s.repo.GetDashboardStats()
}

// ─── Onboarding Requests ────────────────────────────────────────────────────

type SubmitOnboardingInput struct {
	SocietyName        string `json:"societyName" binding:"required"`
	SocietyNameMr      string `json:"societyNameMr"`
	RegistrationNumber string `json:"registrationNumber" binding:"required"`
	Address            string `json:"address"`
	City               string `json:"city"`
	PinCode            string `json:"pinCode"`
	TotalWings         int    `json:"totalWings"`
	TotalFlats         int    `json:"totalFlats"`
	RequesterName      string `json:"requesterName" binding:"required"`
	RequesterPhone     string `json:"requesterPhone" binding:"required"`
	RequesterEmail     string `json:"requesterEmail" binding:"required"`
	RequesterDesignation string `json:"requesterDesignation"`
	CertificateURL     string `json:"certificateUrl"`
	LetterheadURL      string `json:"letterheadUrl"`
}

// ValidateOnboardingInput runs auto-validation checks on the registration request.
type ValidationResult struct {
	RegNumberFormatValid bool   `json:"regNumberFormatValid"`
	PinCodeCityMatch     bool   `json:"pinCodeCityMatch"`
	DuplicateFound       bool   `json:"duplicateFound"`
	Notes                string `json:"notes,omitempty"`
}

func (s *PlatformService) ValidateRequest(input *SubmitOnboardingInput) *ValidationResult {
	result := &ValidationResult{}

	// Check reg number format
	result.RegNumberFormatValid = regNumberPattern.MatchString(strings.ToUpper(input.RegistrationNumber))

	// Check pin code / city consistency (basic: Mumbai = 400xxx, Thane = 400xxx, Pune = 411xxx)
	if input.PinCode != "" && input.City != "" {
		city := strings.ToLower(input.City)
		switch {
		case strings.Contains(city, "mumbai") || strings.Contains(city, "thane"):
			result.PinCodeCityMatch = strings.HasPrefix(input.PinCode, "400")
		case strings.Contains(city, "pune"):
			result.PinCodeCityMatch = strings.HasPrefix(input.PinCode, "411")
		default:
			result.PinCodeCityMatch = true // can't validate, assume ok
		}
	}

	// Check duplicate registration number
	existing, _ := s.repo.ListSocieties(nil)
	for _, soc := range existing {
		if strings.EqualFold(soc.RegistrationNumber, input.RegistrationNumber) {
			result.DuplicateFound = true
			result.Notes = fmt.Sprintf("Duplicate: matches existing society '%s'", soc.Name)
			break
		}
	}

	return result
}

func (s *PlatformService) SubmitOnboardingRequest(input *SubmitOnboardingInput) (*models.PlatformOnboardingRequest, error) {
	req := &models.PlatformOnboardingRequest{
		SocietyName:          input.SocietyName,
		SocietyNameMr:        input.SocietyNameMr,
		RegistrationNumber:   strings.ToUpper(input.RegistrationNumber),
		Address:              input.Address,
		City:                 input.City,
		PinCode:              input.PinCode,
		TotalWings:           input.TotalWings,
		TotalFlats:           input.TotalFlats,
		RequesterName:        input.RequesterName,
		RequesterPhone:       input.RequesterPhone,
		RequesterEmail:       input.RequesterEmail,
		RequesterDesignation: input.RequesterDesignation,
		CertificateURL:       input.CertificateURL,
		LetterheadURL:        input.LetterheadURL,
		Status:               models.OnboardingPending,
	}
	if err := s.repo.CreateOnboardingRequest(req); err != nil {
		return nil, err
	}
	return req, nil
}

func (s *PlatformService) ListRequests(status *models.OnboardingStatus) ([]models.PlatformOnboardingRequest, error) {
	return s.repo.ListOnboardingRequests(status)
}

func (s *PlatformService) GetRequest(id uuid.UUID) (*models.PlatformOnboardingRequest, error) {
	return s.repo.GetOnboardingRequest(id)
}

// ApproveRequest approves a pending request and provisions the society.
func (s *PlatformService) ApproveRequest(requestID, adminID uuid.UUID, notes string) (*models.PlatformSociety, error) {
	req, err := s.repo.GetOnboardingRequest(requestID)
	if err != nil {
		return nil, err
	}
	if req.Status != models.OnboardingPending && req.Status != models.OnboardingInfoRequested {
		return nil, ErrRequestNotPending
	}

	// Create the society
	slug := generateSlug(req.SocietyName, req.City)
	now := time.Now()
	society := &models.PlatformSociety{
		Name:               req.SocietyName,
		NameMr:             req.SocietyNameMr,
		RegistrationNumber: req.RegistrationNumber,
		Slug:               slug,
		Address:            req.Address,
		City:               req.City,
		PinCode:            req.PinCode,
		TotalWings:         req.TotalWings,
		TotalFlats:         req.TotalFlats,
		Status:             models.SocietyActive,
		AdminName:          req.RequesterName,
		AdminEmail:         req.RequesterEmail,
		AdminPhone:         req.RequesterPhone,
		ApprovedByID:       &adminID,
		ApprovedAt:         &now,
	}
	if err := s.repo.CreateSociety(society); err != nil {
		return nil, fmt.Errorf("failed to create society: %w", err)
	}

	// Update request
	req.Status = models.OnboardingApproved
	req.ReviewedByID = &adminID
	req.ReviewedAt = &now
	req.ReviewerNotes = notes
	req.ProvisionedSocID = &society.ID
	if err := s.repo.UpdateOnboardingRequest(req); err != nil {
		return nil, err
	}

	// Audit log
	s.repo.LogAction(&adminID, "APPROVE_REQUEST", "onboarding_request", &requestID,
		fmt.Sprintf("Approved %s → society %s", req.RequestNo, society.Slug), "")

	return society, nil
}

// RejectRequest rejects a pending request with a reason.
func (s *PlatformService) RejectRequest(requestID, adminID uuid.UUID, reason string) error {
	req, err := s.repo.GetOnboardingRequest(requestID)
	if err != nil {
		return err
	}
	if req.Status != models.OnboardingPending && req.Status != models.OnboardingInfoRequested {
		return ErrRequestNotPending
	}

	now := time.Now()
	req.Status = models.OnboardingRejected
	req.ReviewedByID = &adminID
	req.ReviewedAt = &now
	req.RejectReason = reason
	if err := s.repo.UpdateOnboardingRequest(req); err != nil {
		return err
	}

	s.repo.LogAction(&adminID, "REJECT_REQUEST", "onboarding_request", &requestID,
		fmt.Sprintf("Rejected %s: %s", req.RequestNo, reason), "")

	return nil
}

// RequestInfo asks the requester for more information.
func (s *PlatformService) RequestInfo(requestID, adminID uuid.UUID, message string) error {
	req, err := s.repo.GetOnboardingRequest(requestID)
	if err != nil {
		return err
	}
	if req.Status != models.OnboardingPending {
		return ErrRequestNotPending
	}

	req.Status = models.OnboardingInfoRequested
	req.InfoRequest = message
	if err := s.repo.UpdateOnboardingRequest(req); err != nil {
		return err
	}

	s.repo.LogAction(&adminID, "REQUEST_INFO", "onboarding_request", &requestID,
		fmt.Sprintf("Asked for info on %s: %s", req.RequestNo, message), "")

	return nil
}

// ─── Societies ──────────────────────────────────────────────────────────────

func (s *PlatformService) ListSocieties(status *models.SocietyStatus) ([]models.PlatformSociety, error) {
	return s.repo.ListSocieties(status)
}

func (s *PlatformService) GetSociety(id uuid.UUID) (*models.PlatformSociety, error) {
	return s.repo.GetSociety(id)
}

func (s *PlatformService) GetSocietyUsageStats(id uuid.UUID) (*repositories.SocietyUsageStats, error) {
	return s.repo.GetSocietyUsageStats(id)
}

func (s *PlatformService) SuspendSociety(societyID, adminID uuid.UUID, reason string) error {
	soc, err := s.repo.GetSociety(societyID)
	if err != nil {
		return ErrSocietyNotFound
	}
	now := time.Now()
	soc.Status = models.SocietySuspended
	soc.SuspendedAt = &now
	soc.SuspendReason = reason
	if err := s.repo.UpdateSociety(soc); err != nil {
		return err
	}
	s.repo.LogAction(&adminID, "SUSPEND_SOCIETY", "society", &societyID,
		fmt.Sprintf("Suspended %s: %s", soc.Name, reason), "")
	return nil
}

func (s *PlatformService) ActivateSociety(societyID, adminID uuid.UUID) error {
	soc, err := s.repo.GetSociety(societyID)
	if err != nil {
		return ErrSocietyNotFound
	}
	soc.Status = models.SocietyActive
	soc.SuspendedAt = nil
	soc.SuspendReason = ""
	if err := s.repo.UpdateSociety(soc); err != nil {
		return err
	}
	s.repo.LogAction(&adminID, "ACTIVATE_SOCIETY", "society", &societyID,
		fmt.Sprintf("Reactivated %s", soc.Name), "")
	return nil
}

// ─── Audit Log ──────────────────────────────────────────────────────────────

func (s *PlatformService) ListAuditLogs(limit int) ([]models.PlatformAuditLog, error) {
	return s.repo.ListAuditLogs(limit)
}

// ─── Helpers ────────────────────────────────────────────────────────────────

func generateSlug(name, city string) string {
	s := strings.ToLower(name + " " + city)
	// Replace non-alphanumeric with hyphens
	re := regexp.MustCompile(`[^a-z0-9]+`)
	s = re.ReplaceAllString(s, "-")
	s = strings.Trim(s, "-")
	if len(s) > 80 {
		s = s[:80]
	}
	return s
}
