package database

import (
	"log"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

// DefaultSocietyID is the UUID assigned to the existing Sainath Society data
// during the multi-tenancy migration. All pre-existing rows get this value.
var DefaultSocietyID = uuid.MustParse("00000000-0000-0000-0000-000000000001")

// MigrateMultiTenancy runs the one-time migration to:
// 1. Create the default society in platform_societies
// 2. Backfill society_id on all existing rows
// 3. Enable RLS on all tenant-scoped tables
// 4. Drop old unique indexes and create composite ones
func MigrateMultiTenancy(db *gorm.DB) error {
	log.Println("Running multi-tenancy migration...")

	// Step 1: Ensure default society exists in platform_societies
	if err := ensureDefaultSociety(db); err != nil {
		return err
	}

	// Step 2: Backfill society_id on all existing rows
	if err := backfillSocietyID(db); err != nil {
		return err
	}

	// Step 3: Fix unique indexes to be composite (society_id + original column)
	if err := fixUniqueIndexes(db); err != nil {
		return err
	}

	// Step 4: Enable RLS policies
	if err := enableRLS(db); err != nil {
		return err
	}

	log.Println("Multi-tenancy migration completed")
	return nil
}

func ensureDefaultSociety(db *gorm.DB) error {
	var count int64
	db.Model(&models.PlatformSociety{}).Where("id = ?", DefaultSocietyID).Count(&count)
	if count > 0 {
		return nil
	}

	society := &models.PlatformSociety{
		ID:                 DefaultSocietyID,
		Name:               "New Sainath Apartment CHS Ltd",
		NameMr:             "न्यू सई नाथ अपार्टमेंट सहकारी गृहनिर्माण संस्था",
		RegistrationNumber: "BOM/HSG/0001",
		Slug:               "sainath-apt-bhandup",
		Address:            "Bhandup (W), Mumbai",
		City:               "Mumbai",
		PinCode:            "400078",
		State:              "Maharashtra",
		TotalWings:         7,
		TotalFlats:         87,
		Status:             models.SocietyActive,
		AdminName:          "Ganesh Patil",
		AdminEmail:         "ganesh.patil.31@gmail.com",
		AdminPhone:         "9876543210",
	}
	if err := db.Create(society).Error; err != nil {
		return err
	}
	log.Printf("Created default society: %s (%s)", society.Name, DefaultSocietyID)
	return nil
}

func backfillSocietyID(db *gorm.DB) error {
	// All tables that have a society_id column.
	// We update rows where society_id is the zero UUID (not yet assigned).
	tables := []string{
		// Core tables
		"wings", "flats", "members", "users",
		// soc_mitra_* tables
		"soc_mitra_grievances", "soc_mitra_grievance_comments",
		"soc_mitra_vehicles",
		"soc_mitra_notices",
		"soc_mitra_events", "soc_mitra_event_rsvps",
		"soc_mitra_tenants", "soc_mitra_tenant_movements",
		"soc_mitra_financial_transactions",
		"soc_mitra_bylaws", "soc_mitra_bylaw_amendment_logs",
		"soc_mitra_meetings", "soc_mitra_meeting_attendees",
		"soc_mitra_meeting_action_items", "soc_mitra_meeting_documents",
		"soc_mitra_tasks",
		"soc_mitra_documents", "soc_mitra_document_access_grants", "soc_mitra_document_audit_logs",
		"soc_mitra_notifications", "soc_mitra_notification_templates",
		"soc_mitra_polls", "soc_mitra_poll_options", "soc_mitra_poll_votes",
		"soc_mitra_hall_bookings",
		"soc_mitra_inventory_items",
		"soc_mitra_suggestions", "soc_mitra_suggestion_upvotes",
		"soc_mitra_parking_slots",
		"soc_mitra_maintenance_bills",
		"soc_mitra_emergency_contacts",
		"soc_mitra_push_subscriptions",
		"soc_mitra_member_documents",
		"soc_mitra_watchmen",
		"soc_mitra_committee_todos",
		"soc_mitra_member_photos",
		"soc_mitra_workflows", "soc_mitra_workflow_activities",
		"soc_mitra_workflow_activity_comments", "soc_mitra_workflow_activity_attachments",
		"soc_mitra_workflow_audit_logs",
		"soc_mitra_payment_orders", "soc_mitra_society_bank_config",
		"soc_mitra_billing_structures", "soc_mitra_charge_heads", "soc_mitra_bill_line_items",
		"soc_mitra_account_heads",
		"soc_mitra_journal_entries", "soc_mitra_journal_lines",
		"soc_mitra_vendors", "soc_mitra_vendor_payments",
		"soc_mitra_bill_payments",
		"soc_mitra_flat_charge_overrides",
		"soc_mitra_society_settings",
		"soc_mitra_staff", "soc_mitra_staff_attendance", "soc_mitra_staff_salary_payments",
		"soc_mitra_certificates",
		"soc_mitra_amc_contracts", "soc_mitra_service_logs",
		"soc_mitra_visitors", "soc_mitra_frequent_visitors",
		"soc_mitra_budgets", "soc_mitra_budget_line_items",
		"soc_mitra_helpdesk_tickets", "soc_mitra_helpdesk_messages",
		"soc_mitra_elections", "soc_mitra_election_positions",
		"soc_mitra_election_candidates", "soc_mitra_election_votes",
		"soc_mitra_audit_checklists", "soc_mitra_audit_checklist_items",
		"soc_mitra_patrol_checkpoints", "soc_mitra_patrol_rounds",
		"soc_mitra_patrol_scans", "soc_mitra_patrol_incidents",
		"soc_mitra_member_ownerships", "soc_mitra_housing_documents",
	}

	zeroUUID := uuid.Nil.String()

	for _, table := range tables {
		// Check if table exists and has society_id column
		var colCount int64
		db.Raw(`SELECT COUNT(*) FROM information_schema.columns
			WHERE table_name = ? AND column_name = 'society_id'`, table).Scan(&colCount)
		if colCount == 0 {
			continue
		}

		result := db.Exec(
			`UPDATE "`+table+`" SET society_id = ? WHERE society_id = ? OR society_id IS NULL`,
			DefaultSocietyID, zeroUUID,
		)
		if result.Error != nil {
			log.Printf("Warning: failed to backfill %s: %v", table, result.Error)
			continue
		}
		if result.RowsAffected > 0 {
			log.Printf("Backfilled %d rows in %s", result.RowsAffected, table)
		}
	}
	return nil
}

func fixUniqueIndexes(db *gorm.DB) error {
	// Drop old single-column unique indexes and recreate as composite.
	// These are idempotent — IF EXISTS prevents errors on re-run.
	migrations := []string{
		// Wings: name must be unique per society
		`DROP INDEX IF EXISTS idx_wings_name`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_society_wing_name ON wings(society_id, name)`,

		// Flats: flat_number must be unique per society
		`DROP INDEX IF EXISTS idx_flats_flat_number`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_society_flat_number ON flats(society_id, flat_number)`,

		// Members: mobile must be unique per society
		`DROP INDEX IF EXISTS idx_members_mobile`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_society_member_mobile ON members(society_id, mobile)`,

		// Users: email and mobile must be unique per society
		`DROP INDEX IF EXISTS idx_users_email`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_society_user_email ON users(society_id, email)`,
		`DROP INDEX IF EXISTS idx_users_mobile`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_society_user_mobile ON users(society_id, mobile)`,
		`DROP INDEX IF EXISTS idx_users_member_id`,
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_society_user_member ON users(society_id, member_id)`,
	}

	for _, sql := range migrations {
		if err := db.Exec(sql).Error; err != nil {
			log.Printf("Warning: index migration failed: %s — %v", sql, err)
			// Continue — some indexes may not exist in fresh DBs
		}
	}
	return nil
}

func enableRLS(db *gorm.DB) error {
	// RLS policies act as a database-level safety net.
	// Even if application code forgets to filter by society_id,
	// PostgreSQL itself blocks cross-tenant access.
	//
	// The application sets `app.current_society_id` via SET LOCAL
	// in the ActorContextMiddleware for each request.

	tables := []string{
		"wings", "flats", "members", "users",
		"soc_mitra_grievances", "soc_mitra_grievance_comments",
		"soc_mitra_vehicles", "soc_mitra_notices",
		"soc_mitra_events", "soc_mitra_event_rsvps",
		"soc_mitra_tenants", "soc_mitra_tenant_movements",
		"soc_mitra_financial_transactions",
		"soc_mitra_bylaws", "soc_mitra_bylaw_amendment_logs",
		"soc_mitra_meetings", "soc_mitra_meeting_attendees",
		"soc_mitra_meeting_action_items", "soc_mitra_meeting_documents",
		"soc_mitra_tasks",
		"soc_mitra_documents", "soc_mitra_document_access_grants", "soc_mitra_document_audit_logs",
		"soc_mitra_notifications", "soc_mitra_notification_templates",
		"soc_mitra_polls", "soc_mitra_poll_options", "soc_mitra_poll_votes",
		"soc_mitra_hall_bookings", "soc_mitra_inventory_items",
		"soc_mitra_suggestions", "soc_mitra_suggestion_upvotes",
		"soc_mitra_parking_slots", "soc_mitra_maintenance_bills",
		"soc_mitra_emergency_contacts", "soc_mitra_push_subscriptions",
		"soc_mitra_member_documents", "soc_mitra_watchmen",
		"soc_mitra_committee_todos", "soc_mitra_member_photos",
		"soc_mitra_workflows", "soc_mitra_workflow_activities",
		"soc_mitra_workflow_activity_comments", "soc_mitra_workflow_activity_attachments",
		"soc_mitra_workflow_audit_logs",
		"soc_mitra_payment_orders", "soc_mitra_society_bank_config",
		"soc_mitra_billing_structures", "soc_mitra_charge_heads", "soc_mitra_bill_line_items",
		"soc_mitra_account_heads",
		"soc_mitra_journal_entries", "soc_mitra_journal_lines",
		"soc_mitra_vendors", "soc_mitra_vendor_payments",
		"soc_mitra_bill_payments", "soc_mitra_flat_charge_overrides",
		"soc_mitra_society_settings",
		"soc_mitra_staff", "soc_mitra_staff_attendance", "soc_mitra_staff_salary_payments",
		"soc_mitra_certificates",
		"soc_mitra_amc_contracts", "soc_mitra_service_logs",
		"soc_mitra_visitors", "soc_mitra_frequent_visitors",
		"soc_mitra_budgets", "soc_mitra_budget_line_items",
		"soc_mitra_helpdesk_tickets", "soc_mitra_helpdesk_messages",
		"soc_mitra_elections", "soc_mitra_election_positions",
		"soc_mitra_election_candidates", "soc_mitra_election_votes",
		"soc_mitra_audit_checklists", "soc_mitra_audit_checklist_items",
		"soc_mitra_patrol_checkpoints", "soc_mitra_patrol_rounds",
		"soc_mitra_patrol_scans", "soc_mitra_patrol_incidents",
		"soc_mitra_member_ownerships", "soc_mitra_housing_documents",
	}

	for _, table := range tables {
		// Check if table exists
		var exists int64
		db.Raw(`SELECT COUNT(*) FROM information_schema.tables WHERE table_name = ?`, table).Scan(&exists)
		if exists == 0 {
			continue
		}

		// Enable RLS
		db.Exec(`ALTER TABLE "` + table + `" ENABLE ROW LEVEL SECURITY`)

		// Force RLS even for table owner (critical for safety)
		db.Exec(`ALTER TABLE "` + table + `" FORCE ROW LEVEL SECURITY`)

		// Create policy: allow access only when society_id matches the session variable.
		// current_setting returns '' when not set, which won't match any UUID.
		policyName := "tenant_isolation_" + table
		db.Exec(`DROP POLICY IF EXISTS "` + policyName + `" ON "` + table + `"`)
		db.Exec(`CREATE POLICY "` + policyName + `" ON "` + table + `"
			USING (society_id::text = current_setting('app.current_society_id', true))
			WITH CHECK (society_id::text = current_setting('app.current_society_id', true))`)
	}

	log.Println("RLS policies enabled on all tenant-scoped tables")
	return nil
}
