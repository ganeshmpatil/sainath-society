package main

import (
	"github.com/gin-gonic/gin"

	"sainath-society/internal/handlers"
	"sainath-society/internal/middleware"
	"sainath-society/internal/repository"
	"sainath-society/internal/services"
	"sainath-society/pkg/database"
	"sainath-society/pkg/jwt"
)

// SetupRoutes configures all API routes
func SetupRoutes(r *gin.Engine, jwtManager *jwt.Manager, userRepo *repository.UserRepository) {
	// Services
	authService := services.NewAuthService(userRepo, jwtManager)
	otpService := services.NewOTPService(database.DB)
	registrationService := services.NewRegistrationService(database.DB, otpService)

	// Handlers
	authHandler := handlers.NewAuthHandler(authService)
	registrationHandler := handlers.NewRegistrationHandler(registrationService)

	// API v1 group
	api := r.Group("/api/v1")

	// Health check
	api.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "healthy",
			"service": "sainath-society-api",
		})
	})

	// Auth routes (public)
	auth := api.Group("/auth")
	{
		auth.POST("/login", authHandler.Login)
		auth.POST("/refresh", authHandler.RefreshToken)
	}

	// Registration routes (public)
	registration := api.Group("/registration")
	{
		registration.POST("/initiate", registrationHandler.InitiateRegistration)
		registration.POST("/verify-otp", registrationHandler.VerifyOTP)
		registration.POST("/complete", registrationHandler.CompleteRegistration)
		registration.POST("/resend-otp", registrationHandler.ResendOTP)
	}

	// Protected auth routes
	authProtected := api.Group("/auth")
	authProtected.Use(middleware.AuthMiddleware(jwtManager))
	{
		authProtected.GET("/me", authHandler.GetMe)
		authProtected.POST("/logout", authHandler.Logout)
	}
}
