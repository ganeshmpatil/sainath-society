package services

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"log"
	"math/big"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"aangan/internal/models"
	"aangan/internal/repositories"
	"aangan/pkg/jwt"
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
	repo        *repositories.PlatformRepository
	jwtManager  *jwt.Manager
	db          *gorm.DB
	emailSender EmailSender
}

func NewPlatformService(repo *repositories.PlatformRepository, jwtManager *jwt.Manager, db *gorm.DB, emailSender EmailSender) *PlatformService {
	return &PlatformService{repo: repo, jwtManager: jwtManager, db: db, emailSender: emailSender}
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

// ProvisionResult contains everything created during society provisioning.
type ProvisionResult struct {
	Society  *models.PlatformSociety `json:"society"`
	Admin    *models.Member          `json:"admin"`
	Wings    int                     `json:"wingsCreated"`
	Flats    int                     `json:"flatsCreated"`
	TempPass string                  `json:"tempPassword,omitempty"`
}

// ApproveRequest approves a pending request and provisions the full society:
// 1. Creates platform_societies row
// 2. Creates wings (generic A, B, C... based on totalWings)
// 3. Creates flats (4 floors x 4 units per wing, capped at totalFlats)
// 4. Creates the requester as first ADMIN member
// 5. Creates a user account with temporary password
// 6. Sends welcome email with credentials
func (s *PlatformService) ApproveRequest(requestID, adminID uuid.UUID, notes string) (*ProvisionResult, error) {
	req, err := s.repo.GetOnboardingRequest(requestID)
	if err != nil {
		return nil, err
	}
	if req.Status != models.OnboardingPending && req.Status != models.OnboardingInfoRequested {
		return nil, ErrRequestNotPending
	}

	var result ProvisionResult
	tempPassword := generateTempPassword()

	// Run everything in a transaction — if any step fails, roll back all
	err = s.db.Transaction(func(tx *gorm.DB) error {
		now := time.Now()

		// 1. Create the society
		slug := generateSlug(req.SocietyName, req.City)
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
		if err := tx.Create(society).Error; err != nil {
			return fmt.Errorf("create society: %w", err)
		}
		result.Society = society

		// 2. Create wings
		wingNames := generateWingNames(req.TotalWings)
		wings := make([]models.Wing, len(wingNames))
		for i, name := range wingNames {
			wings[i] = models.Wing{
				SocietyID: society.ID,
				Name:      name,
			}
		}
		if len(wings) > 0 {
			if err := tx.Create(&wings).Error; err != nil {
				return fmt.Errorf("create wings: %w", err)
			}
		}
		result.Wings = len(wings)

		// 3. Create flats (distribute evenly across wings)
		flats := generateFlats(society.ID, wings, req.TotalFlats)
		if len(flats) > 0 {
			if err := tx.Create(&flats).Error; err != nil {
				return fmt.Errorf("create flats: %w", err)
			}
		}
		result.Flats = len(flats)

		// 4. Create first admin member (the requester)
		var firstFlatID *uuid.UUID
		if len(flats) > 0 {
			fid := flats[0].ID
			firstFlatID = &fid
		}
		adminMember := &models.Member{
			SocietyID:   society.ID,
			Name:        req.RequesterName,
			Mobile:      req.RequesterPhone,
			Email:       req.RequesterEmail,
			FlatID:      firstFlatID,
			Role:        models.RoleAdmin,
			Designation: req.RequesterDesignation,
			IsActive:    true,
		}
		if err := tx.Create(adminMember).Error; err != nil {
			return fmt.Errorf("create admin member: %w", err)
		}
		result.Admin = adminMember

		// 5. Create user account with temp password
		passHash, err := bcrypt.GenerateFromPassword([]byte(tempPassword), bcrypt.DefaultCost)
		if err != nil {
			return fmt.Errorf("hash password: %w", err)
		}
		user := &models.User{
			SocietyID:          society.ID,
			Email:              req.RequesterEmail,
			Mobile:             req.RequesterPhone,
			PasswordHash:       string(passHash),
			MemberID:           adminMember.ID,
			IsActive:           true,
			MustChangePassword: true, // force password change on first login
		}
		if err := tx.Create(user).Error; err != nil {
			return fmt.Errorf("create user: %w", err)
		}

		// Mark member as registered
		adminMember.IsRegistered = true
		adminMember.RegisteredAt = &now
		adminMember.UserID = &user.ID
		if err := tx.Save(adminMember).Error; err != nil {
			return fmt.Errorf("update admin member: %w", err)
		}

		// 6. Seed default emergency contacts for the new society
		seedSocietyDefaults(tx, society.ID)

		// 7. Update onboarding request
		req.Status = models.OnboardingApproved
		req.ReviewedByID = &adminID
		req.ReviewedAt = &now
		req.ReviewerNotes = notes
		req.ProvisionedSocID = &society.ID
		if err := tx.Save(req).Error; err != nil {
			return fmt.Errorf("update request: %w", err)
		}

		return nil
	})

	if err != nil {
		return nil, fmt.Errorf("provisioning failed: %w", err)
	}

	result.TempPass = tempPassword

	// Audit log (outside transaction — non-critical)
	s.repo.LogAction(&adminID, "APPROVE_REQUEST", "onboarding_request", &requestID,
		fmt.Sprintf("Approved %s → society %s (%d wings, %d flats, admin: %s)",
			req.RequestNo, result.Society.Slug, result.Wings, result.Flats, req.RequesterEmail), "")

	// Send welcome email (async, don't block approval)
	go s.sendWelcomeEmail(req, result.Society, tempPassword)

	return &result, nil
}

// sendWelcomeEmail sends credentials to the new society admin.
func (s *PlatformService) sendWelcomeEmail(req *models.PlatformOnboardingRequest, society *models.PlatformSociety, tempPassword string) {
	if s.emailSender == nil {
		return
	}
	subject := fmt.Sprintf("Welcome to Angaan - %s is now live!", society.Name)
	body := WrapInEmailTemplate(subject, fmt.Sprintf(`
		<p>Dear %s,</p>
		<p>Your society <strong>%s</strong> has been approved and is now live on Angaan!</p>
		<h3>Your Login Credentials</h3>
		<table style="border-collapse:collapse;margin:16px 0">
			<tr><td style="padding:8px 16px;background:#f3f4f6;font-weight:bold">Email</td><td style="padding:8px 16px">%s</td></tr>
			<tr><td style="padding:8px 16px;background:#f3f4f6;font-weight:bold">Temporary Password</td><td style="padding:8px 16px;font-family:monospace;font-size:16px">%s</td></tr>
		</table>
		<p style="color:#ef4444;font-weight:bold">You will be asked to change your password on first login.</p>
		<h3>What's Next?</h3>
		<ol>
			<li>Log in to the app using the credentials above</li>
			<li>Set your new password</li>
			<li>Add your society members (residents)</li>
			<li>Configure wings, flats, and billing structure</li>
		</ol>
		<p>Your society has been set up with <strong>%d wings</strong> and <strong>%d flats</strong>. You can customize these from the admin panel.</p>
	`, req.RequesterName, society.Name, req.RequesterEmail, tempPassword, society.TotalWings, society.TotalFlats))

	_, err := s.emailSender.Send(context.Background(), req.RequesterEmail, subject, body)
	if err != nil {
		log.Printf("Failed to send welcome email to %s: %v", req.RequesterEmail, err)
	} else {
		log.Printf("Welcome email sent to %s for society %s", req.RequesterEmail, society.Name)
	}
}

// generateWingNames creates wing names: A, B, C, ... Z, AA, AB, ...
func generateWingNames(count int) []string {
	names := make([]string, 0, count)
	for i := 0; i < count; i++ {
		if i < 26 {
			names = append(names, string(rune('A'+i)))
		} else {
			names = append(names, fmt.Sprintf("%c%c", rune('A'+(i/26)-1), rune('A'+(i%26))))
		}
	}
	return names
}

// generateFlats creates flats distributed across wings.
// Default: 4 floors, enough units per floor to reach totalFlats.
func generateFlats(societyID uuid.UUID, wings []models.Wing, totalFlats int) []models.Flat {
	if len(wings) == 0 || totalFlats == 0 {
		return nil
	}

	flatsPerWing := totalFlats / len(wings)
	remainder := totalFlats % len(wings)
	floors := 4
	unitsPerFloor := (flatsPerWing + floors - 1) / floors
	if unitsPerFloor < 1 {
		unitsPerFloor = 1
	}

	var flats []models.Flat
	for wi, wing := range wings {
		wingFlats := flatsPerWing
		if wi < remainder {
			wingFlats++ // distribute remainder
		}
		created := 0
		wingID := wing.ID
		for floor := 1; floor <= floors && created < wingFlats; floor++ {
			for unit := 1; unit <= unitsPerFloor && created < wingFlats; unit++ {
				flats = append(flats, models.Flat{
					SocietyID:  societyID,
					FlatNumber: fmt.Sprintf("%s-%d%02d", wing.Name, floor, unit),
					WingID:     &wingID,
					Floor:      floor,
					AreaSqft:   1000,
				})
				created++
			}
		}
	}
	return flats
}

// seedSocietyDefaults creates default data for a new society.
func seedSocietyDefaults(tx *gorm.DB, societyID uuid.UUID) {
	// Default emergency contacts
	contacts := []models.EmergencyContact{
		{TenantScope: models.TenantScope{SocietyID: societyID}, Name: "Police", NameMr: "पोलीस", Category: models.ContactCategoryEmergency, Phone: "100", Role: "Emergency Helpline", RoleMr: "आणीबाणी हेल्पलाइन", SortOrder: 1, IsActive: true},
		{TenantScope: models.TenantScope{SocietyID: societyID}, Name: "Fire Brigade", NameMr: "अग्निशमन दल", Category: models.ContactCategoryEmergency, Phone: "101", Role: "Fire Emergency", RoleMr: "अग्निशमन आणीबाणी", SortOrder: 2, IsActive: true},
		{TenantScope: models.TenantScope{SocietyID: societyID}, Name: "Ambulance", NameMr: "रुग्णवाहिका", Category: models.ContactCategoryEmergency, Phone: "102", Role: "Medical Emergency", RoleMr: "वैद्यकीय आणीबाणी", SortOrder: 3, IsActive: true},
	}
	if err := tx.Create(&contacts).Error; err != nil {
		log.Printf("Warning: failed to seed emergency contacts for society %s: %v", societyID, err)
	}
}

// generateTempPassword creates a random 12-char password.
func generateTempPassword() string {
	const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#"
	b := make([]byte, 12)
	for i := range b {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
		b[i] = chars[n.Int64()]
	}
	return string(b)
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
