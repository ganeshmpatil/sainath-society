package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"sainath-society/internal/dto/response"
)

// PlatformAdminOnly ensures the JWT has role "PLATFORM_ADMIN".
// Must be chained after AuthMiddleware.
func PlatformAdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.GetString("userRole")
		if role != "PLATFORM_ADMIN" {
			c.AbortWithStatusJSON(http.StatusForbidden, response.ErrorResponse{
				Error: "Platform admin access required",
				Code:  "FORBIDDEN",
			})
			return
		}
		c.Next()
	}
}
