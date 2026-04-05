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
