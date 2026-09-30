package database

import (
	"fmt"
	"log"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"sainath-society/internal/config"
	"sainath-society/internal/models"
)

var DB *gorm.DB

// hashPassword generates bcrypt hash for password
func hashPassword(password string) string {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("Failed to hash password: %v", err)
		return ""
	}
	return string(hash)
}

// Connect establishes database connection
func Connect(cfg *config.Config) (*gorm.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName, cfg.DBSSLMode,
	)

	logLevel := logger.Info
	if cfg.Env == "production" {
		logLevel = logger.Error
	}

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logLevel),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	DB = db
	log.Println("Database connected successfully")
	return db, nil
}

// Migrate runs database migrations
func Migrate(db *gorm.DB) error {
	log.Println("Running database migrations...")

	// Order matters: tables with foreign keys must be migrated after their dependencies
	err := db.AutoMigrate(
		&models.Wing{},
		&models.Flat{},
		&models.Permission{},
		&models.RolePermission{},
		&models.OTP{},
	)
	if err != nil {
		return fmt.Errorf("migration failed (phase 1): %w", err)
	}

	// Member depends on Flat
	err = db.AutoMigrate(&models.Member{})
	if err != nil {
		return fmt.Errorf("migration failed (phase 2): %w", err)
	}

	// User depends on Member
	err = db.AutoMigrate(&models.User{})
	if err != nil {
		return fmt.Errorf("migration failed: %w", err)
	}

	// Phase 3: soc_mitra_* domain tables (depend on Member/Flat)
	err = db.AutoMigrate(
		&models.MemberOwnership{},
		&models.HousingDocument{},
		&models.Grievance{},
		&models.GrievanceComment{},
		&models.Vehicle{},
		&models.Notice{},
		&models.Event{},
		&models.EventRSVP{},
		&models.Tenant{},
		&models.TenantMovement{},
		&models.FinancialTransaction{},
		&models.ByLaw{},
		&models.ByLawAmendmentLog{},
		&models.Meeting{},
		&models.MeetingAttendee{},
		&models.MeetingActionItem{},
		&models.MeetingDocument{},
		&models.Task{},
		&models.Document{},
		&models.DocumentAccess{},
		&models.DocumentAuditLog{},
		&models.Notification{},
		&models.NotificationTemplate{},
		&models.Poll{},
		&models.PollOption{},
		&models.PollVote{},
		&models.HallBooking{},
		&models.InventoryItem{},
		&models.Suggestion{},
		&models.SuggestionUpvote{},
		&models.ParkingSlot{},
		&models.MaintenanceBill{},
		&models.EmergencyContact{},
		&models.PushSubscription{},
		&models.MemberDocument{},
		&models.Watchman{},
		&models.CommitteeTodo{},
		&models.MemberPhoto{},
		&models.Workflow{},
		&models.WorkflowActivity{},
		&models.WorkflowActivityComment{},
		&models.WorkflowActivityAttachment{},
		&models.WorkflowAuditLog{},
		&models.PaymentOrder{},
		&models.SocietyBankConfig{},
		&models.BillingStructure{},
		&models.ChargeHead{},
		&models.BillLineItem{},
		&models.AccountHead{},
		&models.JournalEntry{},
		&models.JournalLine{},
		&models.Vendor{},
		&models.VendorPayment{},
		&models.BillPayment{},
		&models.FlatChargeOverride{},
		&models.SocietySetting{},
		&models.Staff{},
		&models.StaffAttendance{},
		&models.StaffSalaryPayment{},
		&models.Certificate{},
		&models.AMCContract{},
		&models.ServiceLog{},
		&models.Visitor{},
		&models.FrequentVisitor{},
	)
	if err != nil {
		return fmt.Errorf("migration failed (phase 3 soc_mitra_*): %w", err)
	}

	log.Println("Database migrations completed")
	return nil
}

// Seed populates initial data
func Seed(db *gorm.DB) error {
	log.Println("Seeding database...")

	// Ensure all 7 wings exist (safe to run on already-seeded DBs)
	if err := ensureWings(db); err != nil {
		return fmt.Errorf("failed to ensure wings: %w", err)
	}

	// Ensure default important contacts exist
	ensureDefaultImportantContacts(db)

	// Ensure society bank config exists (safe to run repeatedly)
	ensureSocietyBankConfig(db)

	// Ensure default billing structure exists
	ensureDefaultBillingStructure(db)

	// Ensure default chart of accounts exists
	ensureDefaultChartOfAccounts(db)

	// Check if already seeded
	var memberCount int64
	db.Model(&models.Member{}).Count(&memberCount)
	if memberCount > 0 {
		log.Println("Database already seeded, skipping...")
		return nil
	}

	// Create wings
	wings := []models.Wing{
		{Name: "A"},
		{Name: "B"},
		{Name: "C"},
		{Name: "D"},
		{Name: "E"},
		{Name: "E1"},
		{Name: "F"},
	}
	if err := db.Create(&wings).Error; err != nil {
		return fmt.Errorf("failed to seed wings: %w", err)
	}

	// Create flats
	flats := createFlats(wings)
	if err := db.Create(&flats).Error; err != nil {
		return fmt.Errorf("failed to seed flats: %w", err)
	}

	// Create admin members (committee)
	adminMembers := createAdminMembers(flats)
	if err := db.Create(&adminMembers).Error; err != nil {
		return fmt.Errorf("failed to seed admin members: %w", err)
	}

	// Create regular members
	regularMembers := createRegularMembers(flats, len(adminMembers))
	if err := db.Create(&regularMembers).Error; err != nil {
		return fmt.Errorf("failed to seed regular members: %w", err)
	}

	// Pre-register one admin user for initial access
	if err := createInitialAdminUser(db, adminMembers[0]); err != nil {
		return fmt.Errorf("failed to create initial admin user: %w", err)
	}

	log.Printf("Seeded %d admin members and %d regular members\n", len(adminMembers), len(regularMembers))
	log.Println("Initial admin user created: chairman@sainath.com / Admin@123")
	return nil
}

func createFlats(wings []models.Wing) []models.Flat {
	// Marathi owner names
	ownerNames := []string{
		"राजेश कुमार", "प्रिया शर्मा", "अमित पाटील", "विक्रम सिंह", "मीरा जोशी",
		"करण मेहता", "अंजली रेड्डी", "सुनील पवार", "अनिता देशमुख", "महेश कुलकर्णी",
		"सविता भोसले", "प्रकाश जाधव", "मंगला शिंदे", "विनोद काळे", "शुभांगी मोरे",
		"राजेंद्र गायकवाड", "स्वाती पाटील", "सुभाष चव्हाण", "ज्योती वाघ", "नितीन साळुंके",
		"प्रीती डांगे", "संजय खैरे", "रेखा निकम", "प्रमोद बोरकर", "सुजाता सावंत",
		"विजय तांबे", "अश्विनी कदम", "गणेश ठाकूर", "वंदना घोरपडे", "अरुण बागल",
		"स्नेहा इंगळे", "दिलीप सोनवणे", "पूजा राणे", "हेमंत गोखले", "आशा वाजे",
		"किरण धनावडे", "नंदिनी केळकर", "मनोज फडके", "उषा परांजपे", "योगेश आठवले",
		"माधवी मुंडे", "संतोष नांदेडकर", "वैशाली सोमण", "राहुल लोंढे", "सरिता चित्रे",
		"अजय बर्वे", "स्मिता गोडबोले", "प्रवीण कारंडे", "मेघा दातार", "सुधीर कुबडे",
	}

	var flats []models.Flat
	flatNum := 0

	for _, wing := range wings {
		for floor := 1; floor <= 4; floor++ {
			for unit := 1; unit <= 8; unit++ {
				wingID := wing.ID
				ownerIndex := flatNum % len(ownerNames)
				flats = append(flats, models.Flat{
					FlatNumber: fmt.Sprintf("%s-%d%02d", wing.Name, floor, unit),
					WingID:     &wingID,
					Floor:      floor,
					AreaSqft:   1200,
					OwnerName:  ownerNames[ownerIndex],
				})
				flatNum++
			}
		}
	}
	return flats
}

func createAdminMembers(flats []models.Flat) []models.Member {
	const committeeMember = "समिती सदस्य"

	adminData := []struct {
		Name        string
		Mobile      string
		Designation string
		FlatIndex   int
	}{
		{"राजेश कुमार", "9876543210", "अध्यक्ष", 0},
		{"प्रिया शर्मा", "9876543211", "सचिव", 1},
		{"अमित पाटील", "9876543212", "खजिनदार", 2},
		{"विक्रम सिंह", "9876543213", committeeMember, 3},
		{"मीरा जोशी", "9876543214", committeeMember, 4},
		{"करण मेहता", "9876543215", committeeMember, 5},
		{"अंजली रेड्डी", "9876543216", committeeMember, 6},
	}

	var members []models.Member
	for _, data := range adminData {
		flatID := flats[data.FlatIndex].ID
		members = append(members, models.Member{
			Name:        data.Name,
			Mobile:      data.Mobile,
			FlatID:      &flatID,
			Role:        models.RoleAdmin,
			Designation: data.Designation,
			IsActive:    true,
		})
	}
	return members
}

func createRegularMembers(flats []models.Flat, startIndex int) []models.Member {
	// Marathi names for regular members
	marathiNames := []string{
		"सुनील पवार", "अनिता देशमुख", "महेश कुलकर्णी", "सविता भोसले", "प्रकाश जाधव",
		"मंगला शिंदे", "विनोद काळे", "शुभांगी मोरे", "राजेंद्र गायकवाड", "स्वाती पाटील",
		"सुभाष चव्हाण", "ज्योती वाघ", "नितीन साळुंके", "प्रीती डांगे", "संजय खैरे",
		"रेखा निकम", "प्रमोद बोरकर", "सुजाता सावंत", "विजय तांबे", "अश्विनी कदम",
		"गणेश ठाकूर", "वंदना घोरपडे", "अरुण बागल", "स्नेहा इंगळे", "दिलीप सोनवणे",
		"पूजा राणे", "हेमंत गोखले", "आशा वाजे", "किरण धनावडे", "नंदिनी केळकर",
		"मनोज फडके", "उषा परांजपे", "योगेश आठवले", "माधवी मुंडे", "संतोष नांदेडकर",
		"वैशाली सोमण", "राहुल लोंढे", "सरिता चित्रे", "अजय बर्वे", "स्मिता गोडबोले",
		"प्रवीण कारंडे", "मेघा दातार", "सुधीर कुबडे", "रश्मी तुपे", "विकास भालेराव",
		"अनघा देशपांडे", "अमोल पंडित", "दीपा जोग", "शिरीष वाड", "कविता आगाशे",
	}

	var members []models.Member
	for i := startIndex; i < len(flats) && i < startIndex+100; i++ {
		flatID := flats[i].ID
		nameIndex := (i - startIndex) % len(marathiNames)
		members = append(members, models.Member{
			Name:     marathiNames[nameIndex],
			Mobile:   fmt.Sprintf("98765%05d", 43217+i-startIndex),
			FlatID:   &flatID,
			Role:     models.RoleMember,
			IsActive: true,
		})
	}
	return members
}

// createInitialAdminUser creates one pre-registered admin for initial system access
func createInitialAdminUser(db *gorm.DB, chairman models.Member) error {
	passwordHash := hashPassword("Admin@123")

	user := &models.User{
		Email:        "chairman@sainath.com",
		Mobile:       chairman.Mobile,
		PasswordHash: passwordHash,
		MemberID:     chairman.ID,
		IsActive:     true,
	}

	if err := db.Create(user).Error; err != nil {
		return err
	}

	// Mark chairman as registered
	chairman.IsRegistered = true
	chairman.UserID = &user.ID
	return db.Save(&chairman).Error
}

// ensureWings creates any missing wings so existing databases get D, E, E1, F.
func ensureWings(db *gorm.DB) error {
	allWings := []string{"A", "B", "C", "D", "E", "E1", "F"}
	for _, name := range allWings {
		var count int64
		db.Model(&models.Wing{}).Where("name = ?", name).Count(&count)
		if count == 0 {
			if err := db.Create(&models.Wing{Name: name}).Error; err != nil {
				return err
			}
			log.Printf("Created missing wing: %s", name)
		}
	}
	return nil
}

// ensureSocietyBankConfig seeds dummy society bank details if none exist.
func ensureSocietyBankConfig(db *gorm.DB) {
	var count int64
	db.Model(&models.SocietyBankConfig{}).Where("is_active = ?", true).Count(&count)
	if count > 0 {
		return
	}
	cfg := &models.SocietyBankConfig{
		AccountName:   "New Sainath Apartment CHS Ltd",
		AccountNumber: "920020043210987",
		BankName:      "State Bank of India",
		BranchName:    "Bhandup West, Mumbai",
		IFSC:          "SBIN0001234",
		UpiID:         "sainathsociety@sbi",
		IsActive:      true,
	}
	if err := db.Create(cfg).Error; err != nil {
		log.Printf("Failed to seed society bank config: %v", err)
	} else {
		log.Println("Seeded society bank config (dummy)")
	}
}

// ensureDefaultImportantContacts seeds emergency & utility contacts if none exist.
func ensureDefaultImportantContacts(db *gorm.DB) {
	var count int64
	db.Model(&models.EmergencyContact{}).Count(&count)
	if count > 0 {
		return
	}

	contacts := []models.EmergencyContact{
		{Name: "Police", NameMr: "पोलीस", Category: models.ContactCategoryEmergency, Phone: "100", Role: "Emergency Helpline", RoleMr: "आणीबाणी हेल्पलाइन", SortOrder: 1, IsActive: true},
		{Name: "Fire Brigade", NameMr: "अग्निशमन दल", Category: models.ContactCategoryEmergency, Phone: "101", Role: "Fire Emergency", RoleMr: "अग्निशमन आणीबाणी", SortOrder: 2, IsActive: true},
		{Name: "Ambulance", NameMr: "रुग्णवाहिका", Category: models.ContactCategoryEmergency, Phone: "102", Role: "Medical Emergency", RoleMr: "वैद्यकीय आणीबाणी", SortOrder: 3, IsActive: true},
		{Name: "Women Helpline", NameMr: "महिला हेल्पलाइन", Category: models.ContactCategoryEmergency, Phone: "1091", Role: "Women Safety", RoleMr: "महिला सुरक्षा", SortOrder: 4, IsActive: true},
		{Name: "Plumber", NameMr: "प्लंबर", Category: models.ContactCategoryUtility, Phone: "", Role: "Plumbing Services", RoleMr: "प्लंबिंग सेवा", SortOrder: 10, IsActive: true},
		{Name: "Electrician", NameMr: "इलेक्ट्रिशियन", Category: models.ContactCategoryUtility, Phone: "", Role: "Electrical Services", RoleMr: "विद्युत सेवा", SortOrder: 11, IsActive: true},
		{Name: "Pest Control", NameMr: "कीटक नियंत्रण", Category: models.ContactCategoryUtility, Phone: "", Role: "Pest Control", RoleMr: "कीटक नियंत्रण सेवा", SortOrder: 12, IsActive: true},
		{Name: "Gas Agency", NameMr: "गॅस एजन्सी", Category: models.ContactCategoryUtility, Phone: "", Role: "LPG Cylinder", RoleMr: "गॅस सिलिंडर", SortOrder: 13, IsActive: true},
		{Name: "Watchman", NameMr: "वॉचमन", Category: models.ContactCategoryUtility, Phone: "", Role: "Society Security", RoleMr: "सोसायटी सुरक्षा", SortOrder: 14, IsActive: true},
	}

	if err := db.Create(&contacts).Error; err != nil {
		log.Printf("Failed to seed important contacts: %v", err)
	} else {
		log.Printf("Seeded %d default important contacts", len(contacts))
	}
}

// ensureDefaultBillingStructure seeds the standard billing structure for Sainath Society.
func ensureDefaultBillingStructure(db *gorm.DB) {
	var count int64
	db.Model(&models.BillingStructure{}).Where("is_active = ?", true).Count(&count)
	if count > 0 {
		return
	}

	// Find chairman member to use as creator
	var chairman models.Member
	if err := db.Where("role = ? AND is_active = ?", "ADMIN", true).First(&chairman).Error; err != nil {
		log.Printf("Skipping billing structure seed: no admin member found")
		return
	}

	bs := &models.BillingStructure{
		Name:         "Standard Monthly",
		NameMr:       "मासिक मानक",
		InterestRate: 18.0, // 18% per annum
		IsActive:     true,
		CreatedByID:  chairman.ID,
	}
	if err := db.Create(bs).Error; err != nil {
		log.Printf("Failed to seed billing structure: %v", err)
		return
	}

	heads := []models.ChargeHead{
		{BillingStructureID: bs.ID, Name: "Maintenance", NameMr: "देखभाल", CalcMethod: models.CalcPerSqft, Rate: 3.50, SortOrder: 1, IsActive: true},
		{BillingStructureID: bs.ID, Name: "Sinking Fund", NameMr: "बुडीत निधी", CalcMethod: models.CalcFixed, Rate: 500, SortOrder: 2, IsActive: true},
		{BillingStructureID: bs.ID, Name: "Repair Fund", NameMr: "दुरुस्ती निधी", CalcMethod: models.CalcFixed, Rate: 300, SortOrder: 3, IsActive: true},
		{BillingStructureID: bs.ID, Name: "Water Charge", NameMr: "पाणी शुल्क", CalcMethod: models.CalcFixed, Rate: 200, SortOrder: 4, IsActive: true},
		{BillingStructureID: bs.ID, Name: "Common Electricity", NameMr: "सामायिक वीज", CalcMethod: models.CalcFixed, Rate: 150, SortOrder: 5, IsActive: true},
		{BillingStructureID: bs.ID, Name: "Lift Maintenance", NameMr: "लिफ्ट देखभाल", CalcMethod: models.CalcFixed, Rate: 100, SortOrder: 6, IsActive: true},
	}
	if err := db.Create(&heads).Error; err != nil {
		log.Printf("Failed to seed charge heads: %v", err)
	} else {
		log.Printf("Seeded billing structure '%s' with %d charge heads", bs.Name, len(heads))
	}
}
