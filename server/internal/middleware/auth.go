package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"sainath-society/internal/dto/response"
	"sainath-society/pkg/jwt"
)

// AuthMiddleware validates JWT tokens
func AuthMiddleware(jwtManager *jwt.Manager) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.ErrorResponse{
				Error: "Authorization header required",
				Code:  "MISSING_AUTH_HEADER",
			})
			return
		}

		// Check Bearer prefix
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.ErrorResponse{
				Error: "Invalid authorization header format",
				Code:  "INVALID_AUTH_FORMAT",
			})
			return
		}

		tokenString := parts[1]

		// Validate token
		claims, err := jwtManager.ValidateAccessToken(tokenString)
		if err != nil {
			if err == jwt.ErrExpiredToken {
				c.AbortWithStatusJSON(http.StatusUnauthorized, response.ErrorResponse{
					Error: "Token has expired",
					Code:  "TOKEN_EXPIRED",
				})
				return
			}
			c.AbortWithStatusJSON(http.StatusUnauthorized, response.ErrorResponse{
				Error: "Invalid token",
				Code:  "INVALID_TOKEN",
			})
			return
		}

		// Set user context
		c.Set("userID", claims.UserID.String())
		c.Set("userEmail", claims.Email)
		c.Set("userRole", claims.Role)
		c.Set("userFlatID", claims.FlatID)
		c.Set("userFlatNumber", claims.FlatNumber)
		c.Set("userPermissions", claims.Permissions)

		c.Next()
	}
}

// OptionalAuthMiddleware tries to authenticate but doesn't require it
func OptionalAuthMiddleware(jwtManager *jwt.Manager) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.Next()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.Next()
			return
		}

		claims, err := jwtManager.ValidateAccessToken(parts[1])
		if err != nil {
			c.Next()
			return
		}

		c.Set("userID", claims.UserID.String())
		c.Set("userEmail", claims.Email)
		c.Set("userRole", claims.Role)
		c.Set("userFlatID", claims.FlatID)
		c.Set("userFlatNumber", claims.FlatNumber)
		c.Set("userPermissions", claims.Permissions)

		c.Next()
	}
}
