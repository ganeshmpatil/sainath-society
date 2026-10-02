package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"aangan/internal/dto/response"
)

// TenantMiddleware ensures every protected request has a valid society context.
// It reads the society ID from the JWT (set by AuthMiddleware) and rejects
// requests that lack one. This runs BEFORE ActorContextMiddleware.
func TenantMiddleware(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		sid := c.GetString("userSocietyID")
		if sid == "" {
			c.AbortWithStatusJSON(http.StatusForbidden, response.ErrorResponse{
				Error: "No society context in token",
				Code:  "MISSING_SOCIETY_CONTEXT",
			})
			return
		}

		societyID, err := uuid.Parse(sid)
		if err != nil || societyID == uuid.Nil {
			c.AbortWithStatusJSON(http.StatusForbidden, response.ErrorResponse{
				Error: "Invalid society context",
				Code:  "INVALID_SOCIETY_ID",
			})
			return
		}

		c.Next()
	}
}
