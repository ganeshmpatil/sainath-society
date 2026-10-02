package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/models"
	"sainath-society/internal/repositories"
)

const actorContextKey = "actorContext"

// ActorContextMiddleware builds a *repositories.ActorContext from the JWT
// claims set by AuthMiddleware and the User row in the database. Every
// protected route that uses the soc_mitra_* repositories must chain this
// middleware after AuthMiddleware.
func ActorContextMiddleware(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userIDStr := c.GetString("userID")
		if userIDStr == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.ErrorResponse{
				Error: "Authentication required",
				Code:  "UNAUTHENTICATED",
			})
			return
		}

		userID, err := uuid.Parse(userIDStr)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.ErrorResponse{
				Error: "Invalid user id in token",
				Code:  "INVALID_TOKEN",
			})
			return
		}

		// Load the user + member in one query (User.MemberID is required).
		var user models.User
		if err := db.Preload("Member").First(&user, "id = ?", userID).Error; err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.ErrorResponse{
				Error: "User not found",
				Code:  "USER_NOT_FOUND",
			})
			return
		}

		// Parse society ID from JWT claims
		societyID := uuid.Nil
		if sid := c.GetString("userSocietyID"); sid != "" {
			if parsed, err := uuid.Parse(sid); err == nil {
				societyID = parsed
			}
		}

		actor := &repositories.ActorContext{
			UserID:    user.ID,
			MemberID:  user.MemberID,
			SocietyID: societyID,
			Role:      models.Role(c.GetString("userRole")),
		}
		if user.Member != nil && user.Member.FlatID != nil {
			flatID := *user.Member.FlatID
			actor.FlatID = &flatID
		}

		// RLS defense-in-depth: set session variable so PostgreSQL row-level
		// security policies can filter by society. We use SET (session-level)
		// because SET LOCAL only works within a transaction.
		// Note: GORM's connection pool may reuse connections, so we ALWAYS
		// set this at the start of every request (never rely on leftover state).
		if societyID != uuid.Nil {
			db.Exec("SET app.current_society_id = ?", societyID.String())
		} else {
			db.Exec("RESET app.current_society_id")
		}

		c.Set(actorContextKey, actor)
		c.Next()
	}
}

// GetActor returns the *ActorContext attached to the current request.
// Panics if ActorContextMiddleware was not chained — callers must use this
// only on routes protected by both AuthMiddleware and ActorContextMiddleware.
func GetActor(c *gin.Context) *repositories.ActorContext {
	v, exists := c.Get(actorContextKey)
	if !exists {
		return nil
	}
	return v.(*repositories.ActorContext)
}
