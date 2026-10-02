package models

import "github.com/google/uuid"

// TenantScope is embedded into every model that belongs to a specific society.
// GORM AutoMigrate will create the society_id column automatically.
// For models with unique constraints that must become composite (e.g., Wing.Name,
// Flat.FlatNumber), define SocietyID directly in the model struct instead.
type TenantScope struct {
	SocietyID uuid.UUID `gorm:"type:uuid;not null;index:idx_society_id" json:"societyId"`
}
