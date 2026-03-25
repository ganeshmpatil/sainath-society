package models

import (
	"github.com/google/uuid"
)

// Resource represents a system resource
type Resource string

const (
	ResourceGrievances  Resource = "grievances"
	ResourceFinance     Resource = "finance"
	ResourceNotices     Resource = "notices"
	ResourceVehicles    Resource = "vehicles"
	ResourcePolls       Resource = "polls"
	ResourceMeetings    Resource = "meetings"
	ResourceHallBooking Resource = "hall_booking"
	ResourceInventory   Resource = "inventory"
	ResourceBylaws      Resource = "bylaws"
	ResourceUsers       Resource = "users"
	ResourceFlats       Resource = "flats"
	ResourceResidents   Resource = "residents"
	ResourceTasks       Resource = "tasks"
	ResourceMoveInOut   Resource = "move_in_out"
	ResourceSuggestions Resource = "suggestions"
	ResourceDecisions   Resource = "decisions"
)

// Action represents an action on a resource
type Action string

const (
	ActionCreate  Action = "create"
	ActionReadOwn Action = "read_own"
	ActionReadAll Action = "read_all"
	ActionUpdate  Action = "update"
	ActionDelete  Action = "delete"
	ActionVote    Action = "vote"
)

// Permission represents a permission entry
type Permission struct {
	ID       uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Resource Resource  `gorm:"type:varchar(50);not null" json:"resource"`
	Action   Action    `gorm:"type:varchar(20);not null" json:"action"`
}

func (Permission) TableName() string {
	return "permissions"
}

// RolePermission maps roles to permissions
type RolePermission struct {
	ID           uuid.UUID `gorm:"type:uuid;primary_key;default:gen_random_uuid()" json:"id"`
	Role         Role      `gorm:"type:varchar(20);not null" json:"role"`
	PermissionID uuid.UUID `gorm:"type:uuid;not null" json:"permissionId"`

	// Relations
	Permission Permission `gorm:"foreignKey:PermissionID" json:"permission,omitempty"`
}

func (RolePermission) TableName() string {
	return "role_permissions"
}

// RolePermissionsMap defines permissions for each role
// This is used for quick lookup without DB queries
var RolePermissionsMap = map[Role][]string{
	RoleMember: {
		// Grievances
		"grievances:create",
		"grievances:read_own",
		// Finance
		"finance:read_own",
		// Notices
		"notices:read_all",
		// Vehicles
		"vehicles:create",
		"vehicles:read_own",
		"vehicles:update",
		"vehicles:delete",
		// Polls
		"polls:read_all",
		"polls:vote",
		// Meetings
		"meetings:read_all",
		// Hall Booking
		"hall_booking:create",
		"hall_booking:read_own",
		// Residents
		"residents:read_all",
		// Bylaws
		"bylaws:read_all",
		// Inventory
		"inventory:read_all",
		// Suggestions
		"suggestions:create",
		"suggestions:read_all",
		"suggestions:vote",
		// Decisions
		"decisions:read_all",
		// Flats
		"flats:read_own",
	},
	RoleAdmin: {
		// Full access - represented by wildcard in code
		"*:*",
	},
}

// GetPermissionsForRole returns the permissions list for a role
func GetPermissionsForRole(role Role) []string {
	if role == RoleAdmin {
		// Return all possible permissions for admin
		return getAllPermissions()
	}
	return RolePermissionsMap[role]
}

// getAllPermissions returns all possible permission strings
func getAllPermissions() []string {
	resources := []Resource{
		ResourceGrievances, ResourceFinance, ResourceNotices, ResourceVehicles,
		ResourcePolls, ResourceMeetings, ResourceHallBooking, ResourceInventory,
		ResourceBylaws, ResourceUsers, ResourceFlats, ResourceResidents,
		ResourceTasks, ResourceMoveInOut, ResourceSuggestions, ResourceDecisions,
	}
	actions := []Action{ActionCreate, ActionReadOwn, ActionReadAll, ActionUpdate, ActionDelete, ActionVote}

	var permissions []string
	for _, r := range resources {
		for _, a := range actions {
			permissions = append(permissions, string(r)+":"+string(a))
		}
	}
	return permissions
}
