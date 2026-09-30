package main

import (
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"sainath-society/internal/handlers"
	"sainath-society/internal/middleware"
	"sainath-society/internal/repository"
	"sainath-society/internal/services"
	"sainath-society/pkg/database"
	"sainath-society/pkg/jwt"
)

// SetupRoutes configures all API routes
func SetupRoutes(
	r *gin.Engine,
	jwtManager *jwt.Manager,
	userRepo *repository.UserRepository,
	domain *DomainRepositories,
	notifier *services.Notifier,
	db *gorm.DB,
	vapidPublicKey string,
	rzpKeyID, rzpKeySecret string,
) {
	// Services
	authService := services.NewAuthService(userRepo, jwtManager)
	otpService := services.NewOTPService(database.DB)
	registrationService := services.NewRegistrationService(database.DB, otpService)

	// Handlers
	authHandler := handlers.NewAuthHandler(authService)
	registrationHandler := handlers.NewRegistrationHandler(registrationService)
	grievanceHandler := handlers.NewGrievanceHandler(domain.Grievance, domain.Notification, notifier)
	taskHandler := handlers.NewTaskHandler(domain.Task, notifier)
	vehicleHandler := handlers.NewVehicleHandler(domain.Vehicle)
	noticeHandler := handlers.NewNoticeHandler(domain.Notice, notifier)
	eventHandler := handlers.NewEventHandler(domain.Event, notifier)
	tenantHandler := handlers.NewTenantHandler(domain.Tenant, notifier)
	transactionHandler := handlers.NewTransactionHandler(domain.Transaction)
	bylawHandler := handlers.NewByLawHandler(domain.ByLaw)
	meetingHandler := handlers.NewMeetingHandler(domain.Meeting, notifier)
	ownershipHandler := handlers.NewOwnershipHandler(domain.Ownership)
	documentHandler := handlers.NewDocumentHandler(domain.Document)
	memberDocumentHandler := handlers.NewMemberDocumentHandler(domain.MemberDocument)
	pollHandler := handlers.NewPollHandler(domain.Poll, notifier)
	hallBookingHandler := handlers.NewHallBookingHandler(domain.HallBooking, notifier)
	inventoryHandler := handlers.NewInventoryHandler(domain.Inventory)
	suggestionHandler := handlers.NewSuggestionHandler(domain.Suggestion)
	parkingHandler := handlers.NewParkingHandler(domain.Parking)
	billHandler := handlers.NewBillHandler(domain.Bill, notifier)
	residentHandler := handlers.NewResidentHandler(domain.Member, db)
	flatHandler := handlers.NewFlatHandler(domain.Flat)
	notificationHandler := handlers.NewNotificationHandler(domain.Notification, domain.Member)
	emergencyContactHandler := handlers.NewEmergencyContactHandler(domain.EmergencyContact)
	pushHandler := handlers.NewPushHandler(domain.PushSubscription, vapidPublicKey)
	watchmanHandler := handlers.NewWatchmanHandler(domain.Watchman)
	committeeTodoHandler := handlers.NewCommitteeTodoHandler(domain.CommitteeTodo)
	workflowHandler := handlers.NewWorkflowHandler(domain.Workflow, notifier)
	billingStructureHandler := handlers.NewBillingStructureHandler(domain.BillingStructure)
	paymentHandler := handlers.NewPaymentHandler(domain.Payment, domain.Bill, rzpKeyID, rzpKeySecret)
	accountHeadHandler := handlers.NewAccountHeadHandler(domain.AccountHead)
	journalHandler := handlers.NewJournalHandler(domain.Journal, domain.AccountHead)
	defaulterHandler := handlers.NewDefaulterHandler(domain.Defaulter)

	// API v1 group
	api := r.Group("/api/v1")

	// Health check
	api.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "healthy",
			"service": "sainath-society-api",
		})
	})

	// App version check (public — no auth needed)
	api.GET("/version", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"latestVersion": "1.0.1",
			"minVersion":    "1.0.0",
			"downloadUrl":   "https://github.com/ganeshmpatil/sainath-society/releases/download/v1.0.0/sainath-society.apk",
			"releaseNotes":  "In-app update support added",
			"releaseNotesMr": "अ\u200dॅपमध्ये अपडेट सुविधा जोडली",
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
		authProtected.PUT("/password", authHandler.ChangePassword)
		authProtected.POST("/admin-reset-password", authHandler.AdminResetPassword)
	}

	// Protected soc_mitra_* routes — every route below passes through both
	// AuthMiddleware (JWT validation) and ActorContextMiddleware (builds the
	// ActorContext used by repositories for row-level ACL).
	protected := api.Group("/")
	protected.Use(middleware.AuthMiddleware(jwtManager))
	protected.Use(middleware.ActorContextMiddleware(db))
	{
		// Grievances — members see own; admins see all.
		g := protected.Group("/grievances")
		g.POST("", grievanceHandler.Create)
		g.GET("", grievanceHandler.List)
		g.GET("/:id", grievanceHandler.GetByID)
		g.PATCH("/:id/status", grievanceHandler.UpdateStatus)
		g.POST("/:id/comments", grievanceHandler.AddComment)

		// Tasks — members see own; admins can assign to anyone.
		t := protected.Group("/tasks")
		t.POST("", taskHandler.Create)
		t.GET("", taskHandler.ListPending)
		t.GET("/:id", taskHandler.GetByID)
		t.PATCH("/:id/status", taskHandler.UpdateStatus)

		// Vehicles — owner + admin visibility.
		v := protected.Group("/vehicles")
		v.POST("", vehicleHandler.Create)
		v.GET("", vehicleHandler.List)
		v.GET("/:id", vehicleHandler.GetByID)
		v.PATCH("/:id", vehicleHandler.Update)
		v.DELETE("/:id", vehicleHandler.Delete)

		// Notices — admin writes, everyone reads.
		n := protected.Group("/notices")
		n.POST("", noticeHandler.Create)
		n.POST("/with-attachment", noticeHandler.CreateWithAttachment)
		n.GET("", noticeHandler.List)
		n.GET("/:id", noticeHandler.GetByID)
		n.GET("/:id/attachment", noticeHandler.DownloadAttachment)
		n.PATCH("/:id", noticeHandler.Update)
		n.DELETE("/:id", noticeHandler.Delete)

		// Events — admin creates, members RSVP.
		e := protected.Group("/events")
		e.POST("", eventHandler.Create)
		e.GET("/upcoming", eventHandler.ListUpcoming)
		e.GET("", eventHandler.ListAll)
		e.GET("/:id", eventHandler.GetByID)
		e.POST("/:id/rsvp", eventHandler.RSVP)

		// Tenants — landlord + admin.
		tn := protected.Group("/tenants")
		tn.POST("", tenantHandler.Create)
		tn.GET("", tenantHandler.List)
		tn.GET("/:id", tenantHandler.GetByID)
		tn.POST("/:id/approve", tenantHandler.Approve)
		tn.POST("/:id/movements", tenantHandler.RecordMovement)
		tn.GET("/:id/movements", tenantHandler.ListMovements)

		// Financial transactions — member sees own, admin sees all.
		tx := protected.Group("/transactions")
		tx.POST("", transactionHandler.Create)
		tx.GET("", transactionHandler.List)
		tx.GET("/summary", transactionHandler.Summary)
		tx.GET("/:id", transactionHandler.GetByID)
		tx.POST("/:id/mark-paid", transactionHandler.MarkPaid)

		// Bylaws — public read; admin write.
		bl := protected.Group("/bylaws")
		bl.POST("", bylawHandler.Create)
		bl.GET("", bylawHandler.List)
		bl.GET("/:id", bylawHandler.GetByID)
		bl.PATCH("/:id/amend", bylawHandler.Amend)

		// Meetings — committee-only hidden from members.
		mt := protected.Group("/meetings")
		mt.POST("", meetingHandler.Create)
		mt.GET("", meetingHandler.List)
		mt.GET("/my-action-items", meetingHandler.MyActionItems)
		mt.GET("/:id", meetingHandler.GetByID)
		mt.POST("/:id/attendance", meetingHandler.MarkAttendance)
		mt.POST("/:id/minutes", meetingHandler.SaveMinutes)
		mt.POST("/:id/action-items", meetingHandler.AddActionItem)

		// Member ownership + housing documents.
		own := protected.Group("/ownerships")
		own.POST("", ownershipHandler.Create)
		own.GET("", ownershipHandler.List)
		own.GET("/:id", ownershipHandler.GetByID)
		own.POST("/:id/documents", ownershipHandler.AddDocument)
		own.GET("/:id/documents", ownershipHandler.ListDocuments)

		// Document vault.
		doc := protected.Group("/documents")
		doc.POST("", documentHandler.Create)
		doc.GET("", documentHandler.List)
		doc.GET("/:id", documentHandler.GetByID)
		doc.POST("/:id/grant", documentHandler.Grant)
		doc.POST("/:id/archive", documentHandler.Archive)

		// Member document locker (personal ID docs stored compressed in DB).
		mdoc := protected.Group("/member-documents")
		mdoc.POST("/upload", memberDocumentHandler.Upload)
		mdoc.GET("", memberDocumentHandler.List)
		mdoc.GET("/:id", memberDocumentHandler.GetByID)
		mdoc.GET("/:id/download", memberDocumentHandler.Download)
		mdoc.DELETE("/:id", memberDocumentHandler.Delete)

		// Residents (Member roster — everyone sees, admin mutates).
		res := protected.Group("/residents")
		res.POST("", residentHandler.Create)
		res.GET("", residentHandler.List)
		res.GET("/:id", residentHandler.GetByID)
		res.PUT("/:id", residentHandler.Update)
		res.DELETE("/:id", residentHandler.Deactivate)
		res.PUT("/:id/photo", residentHandler.UploadPhoto)
		res.GET("/:id/photo", residentHandler.GetPhoto)
		res.DELETE("/:id/photo", residentHandler.DeletePhoto)

		// Flats
		fl := protected.Group("/flats")
		fl.POST("", flatHandler.Create)
		fl.GET("", flatHandler.List)
		fl.GET("/wings", flatHandler.ListWings)
		fl.GET("/:id", flatHandler.GetByID)
		fl.PUT("/:id", flatHandler.Update)

		// Polls — admins create/close, members vote.
		pl := protected.Group("/polls")
		pl.POST("", pollHandler.Create)
		pl.GET("", pollHandler.List)
		pl.GET("/:id", pollHandler.GetByID)
		pl.GET("/:id/results", pollHandler.Results)
		pl.POST("/:id/publish", pollHandler.Publish)
		pl.POST("/:id/close", pollHandler.Close)
		pl.POST("/:id/vote", pollHandler.Vote)

		// Hall bookings.
		hb := protected.Group("/hall-bookings")
		hb.POST("", hallBookingHandler.Create)
		hb.GET("", hallBookingHandler.List)
		hb.GET("/availability", hallBookingHandler.CheckAvailability)
		hb.GET("/:id", hallBookingHandler.GetByID)
		hb.POST("/:id/decide", hallBookingHandler.Decide)
		hb.POST("/:id/cancel", hallBookingHandler.Cancel)

		// Inventory.
		inv := protected.Group("/inventory")
		inv.POST("", inventoryHandler.Create)
		inv.GET("", inventoryHandler.List)
		inv.GET("/:id", inventoryHandler.GetByID)
		inv.PATCH("/:id", inventoryHandler.Update)
		inv.DELETE("/:id", inventoryHandler.Delete)

		// Suggestions with upvote + admin response.
		sg := protected.Group("/suggestions")
		sg.POST("", suggestionHandler.Create)
		sg.GET("", suggestionHandler.List)
		sg.GET("/:id", suggestionHandler.GetByID)
		sg.POST("/:id/upvote", suggestionHandler.Upvote)
		sg.POST("/:id/respond", suggestionHandler.Respond)

		// Parking slots + allocation.
		pk := protected.Group("/parking")
		pk.POST("/slots", parkingHandler.Create)
		pk.GET("/slots", parkingHandler.List)
		pk.GET("/slots/:id", parkingHandler.GetByID)
		pk.POST("/slots/:id/allocate", parkingHandler.Allocate)
		pk.POST("/slots/:id/release", parkingHandler.Release)

		// Notifications — inbox + admin email broadcast.
		notif := protected.Group("/notifications")
		notif.GET("/inbox", notificationHandler.ListInbox)
		notif.GET("/unread-count", notificationHandler.UnreadCount)
		notif.POST("/:id/read", notificationHandler.MarkRead)
		notif.POST("/send-email", notificationHandler.SendEmail)
		notif.POST("/send-email-all", notificationHandler.SendEmailToAll)

		// Emergency contacts — everyone reads, admin manages.
		ec := protected.Group("/emergency-contacts")
		ec.GET("", emergencyContactHandler.List)
		ec.POST("", emergencyContactHandler.Create)
		ec.PATCH("/:id", emergencyContactHandler.Update)
		ec.DELETE("/:id", emergencyContactHandler.Delete)

		// Web Push subscription management.
		push := protected.Group("/push")
		push.GET("/vapid-key", pushHandler.VAPIDPublicKey)
		push.POST("/subscribe", pushHandler.Subscribe)
		push.POST("/unsubscribe", pushHandler.Unsubscribe)
		push.POST("/register-device", pushHandler.RegisterDevice)
		push.POST("/unregister-device", pushHandler.UnregisterDevice)

		// Watchmen — everyone reads, admin manages.
		wm := protected.Group("/watchmen")
		wm.POST("", watchmanHandler.Create)
		wm.GET("", watchmanHandler.List)
		wm.GET("/:id", watchmanHandler.GetByID)
		wm.PATCH("/:id", watchmanHandler.Update)
		wm.DELETE("/:id", watchmanHandler.Delete)

		// Committee calendar todos — everyone reads, admin manages.
		ct := protected.Group("/committee-calendar")
		ct.POST("", committeeTodoHandler.Create)
		ct.GET("", committeeTodoHandler.List)
		ct.GET("/:id", committeeTodoHandler.GetByID)
		ct.PATCH("/:id", committeeTodoHandler.Update)
		ct.PATCH("/:id/status", committeeTodoHandler.UpdateStatus)
		ct.DELETE("/:id", committeeTodoHandler.Delete)

		// Workflows — admin creates/manages, members view.
		wf := protected.Group("/workflows")
		wf.POST("", workflowHandler.Create)
		wf.GET("", workflowHandler.List)
		wf.GET("/components", workflowHandler.ListComponents)
		wf.GET("/templates", workflowHandler.ListTemplates)
		wf.POST("/seed-templates", workflowHandler.SeedTemplates)
		wf.GET("/:id", workflowHandler.GetByID)
		wf.PATCH("/:id", workflowHandler.Update)
		wf.PATCH("/:id/status", workflowHandler.UpdateStatus)
		wf.DELETE("/:id", workflowHandler.Delete)
		wf.POST("/:id/instantiate", workflowHandler.Instantiate)
		wf.POST("/:id/activities", workflowHandler.AddActivity)
		wf.PATCH("/:id/activities/:actId", workflowHandler.UpdateActivity)
		wf.PATCH("/:id/activities/:actId/status", workflowHandler.UpdateActivityStatus)
		wf.POST("/:id/activities/reorder", workflowHandler.ReorderActivities)
		wf.DELETE("/:id/activities/:actId", workflowHandler.DeleteActivity)
		wf.POST("/:id/activities/:actId/comments", workflowHandler.AddComment)
		wf.POST("/:id/activities/:actId/attachments", workflowHandler.UploadAttachment)
		wf.GET("/:id/activities/:actId/attachments/:attId/download", workflowHandler.DownloadAttachment)
		wf.GET("/:id/audit-log", workflowHandler.AuditLog)

		// Finance: maintenance bill generation + dues.
		fn := protected.Group("/finance")
		fn.POST("/bills/generate", billHandler.Generate)
		fn.GET("/bills", billHandler.List)
		fn.GET("/bills/pending-dues", billHandler.PendingDues)
		fn.GET("/bills/:id", billHandler.GetByID)
		fn.POST("/bills/:id/mark-paid", billHandler.MarkPaid)

		// Billing structure: charge heads + rate configuration.
		bs := fn.Group("/billing-structure")
		bs.GET("/active", billingStructureHandler.GetActive)
		bs.GET("/preview", billingStructureHandler.Preview)
		bs.GET("", billingStructureHandler.List)
		bs.POST("", billingStructureHandler.Create)
		bs.PATCH("/:id", billingStructureHandler.Update)
		bs.POST("/:id/charge-heads", billingStructureHandler.AddChargeHead)
		bs.PATCH("/:id/charge-heads/:chId", billingStructureHandler.UpdateChargeHead)
		bs.DELETE("/:id/charge-heads/:chId", billingStructureHandler.DeleteChargeHead)

		// Chart of Accounts: admin manages, used for double-entry bookkeeping.
		coa := fn.Group("/accounts")
		coa.GET("/tree", accountHeadHandler.ListTree)
		coa.GET("", accountHeadHandler.ListAll)
		coa.GET("/leaf", accountHeadHandler.ListLeaf)
		coa.GET("/:id", accountHeadHandler.GetByID)
		coa.POST("", accountHeadHandler.Create)
		coa.PATCH("/:id", accountHeadHandler.Update)
		coa.DELETE("/:id", accountHeadHandler.Delete)

		// Journal entries: double-entry bookkeeping.
		je := fn.Group("/journal")
		je.GET("", journalHandler.List)
		je.GET("/:id", journalHandler.GetByID)
		je.POST("", journalHandler.Create)
		je.GET("/ledger/:accountId", journalHandler.Ledger)
		je.GET("/trial-balance", journalHandler.TrialBalance)

		// Defaulter register, member statement, collection dashboard.
		df := fn.Group("/defaulters")
		df.GET("/register", defaulterHandler.Register)
		df.GET("/summary", defaulterHandler.Summary)
		df.GET("/my-statement", defaulterHandler.MyStatement)
		df.GET("/statement/:memberId", defaulterHandler.MemberStatement)

		// Payments: Razorpay gateway + bank details.
		pay := protected.Group("/payments")
		pay.GET("/config", paymentHandler.GetConfig)
		pay.GET("/bank-details", paymentHandler.GetBankDetails)
		pay.POST("/create-order", paymentHandler.CreateOrder)
		pay.POST("/verify", paymentHandler.VerifyPayment)
		pay.GET("", paymentHandler.ListPayments)
	}
}
