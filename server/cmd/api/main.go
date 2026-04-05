package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/gin-gonic/gin"

	"sainath-society/internal/config"
	"sainath-society/internal/middleware"
	"sainath-society/internal/repositories"
	"sainath-society/internal/repository"
	"sainath-society/internal/services"
	"sainath-society/pkg/database"
	"sainath-society/pkg/jwt"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Set Gin mode
	if cfg.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Connect to database
	db, err := database.Connect(cfg)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Run migrations
	if err := database.Migrate(db); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Seed database
	if err := database.Seed(db); err != nil {
		log.Fatalf("Failed to seed database: %v", err)
	}

	// Initialize JWT manager
	jwtManager := jwt.NewManager(
		cfg.JWTSecret,
		cfg.JWTAccessExpiry,
		cfg.JWTRefreshExpiry,
	)

	// Legacy single-user repo
	userRepo := repository.NewUserRepository(db)

	// soc_mitra_* domain repositories (row-level ACL aware)
	domainRepos := &DomainRepositories{
		Ownership:     repositories.NewOwnershipRepository(db),
		Grievance:     repositories.NewGrievanceRepository(db),
		Vehicle:       repositories.NewVehicleRepository(db),
		Notice:        repositories.NewNoticeRepository(db),
		Event:         repositories.NewEventRepository(db),
		Tenant:        repositories.NewTenantRepository(db),
		Transaction:   repositories.NewTransactionRepository(db),
		ByLaw:         repositories.NewByLawRepository(db),
		Meeting:       repositories.NewMeetingRepository(db),
		Task:          repositories.NewTaskRepository(db),
		Document:      repositories.NewDocumentRepository(db),
		Notification:  repositories.NewNotificationRepository(db),
		Poll:          repositories.NewPollRepository(db),
		HallBooking:   repositories.NewHallBookingRepository(db),
		Inventory:     repositories.NewInventoryRepository(db),
		Suggestion:    repositories.NewSuggestionRepository(db),
		Parking:       repositories.NewParkingRepository(db),
		Bill:          repositories.NewBillRepository(db),
		Member:        repositories.NewMemberRepository(db),
		Flat:          repositories.NewFlatRepository(db),
	}

	// Create Gin router
	r := gin.New()

	// Global middleware
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(middleware.CORSMiddleware(cfg.AllowedOrigins))

	// Setup routes
	SetupRoutes(r, jwtManager, userRepo, domainRepos, db)

	// Start notification worker (WhatsApp dispatcher)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	worker := services.NewNotificationWorker(domainRepos.Notification, services.NewMockWhatsAppSender())
	go worker.Run(ctx)

	// Start server
	go func() {
		addr := ":" + cfg.Port
		log.Printf("Server starting on %s", addr)
		log.Printf("Environment: %s", cfg.Env)
		if err := r.Run(addr); err != nil {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	cancel()
}

// DomainRepositories bundles every soc_mitra_* repository so routes can
// receive a single dependency instead of a dozen parameters.
type DomainRepositories struct {
	Ownership    *repositories.OwnershipRepository
	Grievance    *repositories.GrievanceRepository
	Vehicle      *repositories.VehicleRepository
	Notice       *repositories.NoticeRepository
	Event        *repositories.EventRepository
	Tenant       *repositories.TenantRepository
	Transaction  *repositories.TransactionRepository
	ByLaw        *repositories.ByLawRepository
	Meeting      *repositories.MeetingRepository
	Task         *repositories.TaskRepository
	Document     *repositories.DocumentRepository
	Notification *repositories.NotificationRepository
	Poll         *repositories.PollRepository
	HallBooking  *repositories.HallBookingRepository
	Inventory    *repositories.InventoryRepository
	Suggestion   *repositories.SuggestionRepository
	Parking      *repositories.ParkingRepository
	Bill         *repositories.BillRepository
	Member       *repositories.MemberRepository
	Flat         *repositories.FlatRepository
}
