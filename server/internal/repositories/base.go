package repositories

import (
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/models"
)

// ErrForbidden is returned when a non-admin actor tries to access a row they
// do not own. Handlers map this to HTTP 403.
var ErrForbidden = errors.New("forbidden: resource not owned by actor")

// ErrNotFound is returned when the row does not exist.
var ErrNotFound = errors.New("resource not found")

// ActorContext represents the authenticated caller performing a data operation.
// It is the single source of truth used by every repository to decide row
// visibility. Handlers/middleware must populate it from the JWT claims.
type ActorContext struct {
	UserID   uuid.UUID
	MemberID uuid.UUID
	Role     models.Role
	FlatID   *uuid.UUID // flat the actor owns (if any)
}

// IsAdmin is a convenience helper.
func (a *ActorContext) IsAdmin() bool { return a.Role == models.RoleAdmin }

// ScopeOwnedOrAdmin attaches a WHERE clause that keeps the row only if the
// actor is an admin OR the row's owner column matches the actor's MemberID.
//
//   - ownerColumn is the snake_case DB column used for row-level ownership,
//     e.g. "raised_by_member_id", "owner_member_id", "member_id".
//
// Usage:
//
//	q := db.Model(&models.Grievance{})
//	q = ScopeOwnedOrAdmin(q, actor, "raised_by_member_id")
//	var rows []models.Grievance
//	q.Find(&rows)
func ScopeOwnedOrAdmin(q *gorm.DB, actor *ActorContext, ownerColumn string) *gorm.DB {
	if actor == nil {
		// no actor → nothing is visible
		return q.Where("1 = 0")
	}
	if actor.IsAdmin() {
		return q
	}
	return q.Where(ownerColumn+" = ?", actor.MemberID)
}

// ScopeFlatOrAdmin scopes rows where the flat_id matches the actor's flat
// (for flat-scoped resources such as transactions for a flat, tenants, etc.).
func ScopeFlatOrAdmin(q *gorm.DB, actor *ActorContext, flatColumn string) *gorm.DB {
	if actor == nil {
		return q.Where("1 = 0")
	}
	if actor.IsAdmin() {
		return q
	}
	if actor.FlatID == nil {
		return q.Where("1 = 0")
	}
	return q.Where(flatColumn+" = ?", *actor.FlatID)
}

// AssertOwnerOrAdmin returns ErrForbidden if the actor is not an admin AND is
// not the stated owner of the resource.
func AssertOwnerOrAdmin(actor *ActorContext, ownerID uuid.UUID) error {
	if actor == nil {
		return ErrForbidden
	}
	if actor.IsAdmin() {
		return nil
	}
	if actor.MemberID == ownerID {
		return nil
	}
	return ErrForbidden
}
