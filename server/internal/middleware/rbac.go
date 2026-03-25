package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"sainath-society/internal/dto/response"
	"sainath-society/internal/models"
)

// DataScope represents the scope of data access
type DataScope string

const (
	ScopeOwn DataScope = "own"
	ScopeAll DataScope = "all"
)

// RequirePermission checks if user has the required permission
func RequirePermission(resource models.Resource, action models.Action) gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.GetString("userRole")

		// Admin has full access
		if role == string(models.RoleAdmin) {
			c.Next()
			return
		}

		permissions, exists := c.Get("userPermissions")
		if !exists {
			c.AbortWithStatusJSON(http.StatusForbidden, response.ErrorResponse{
				Error: "Permission denied",
				Code:  "FORBIDDEN",
			})
			return
		}

		required := string(resource) + ":" + string(action)
		permList := permissions.([]string)

		for _, p := range permList {
			if p == required {
				c.Next()
				return
			}
		}

		c.AbortWithStatusJSON(http.StatusForbidden, response.ErrorResponse{
			Error:   "Permission denied",
			Code:    "FORBIDDEN",
			Details: "Required permission: " + required,
		})
	}
}

// RequireRole checks if user has one of the required roles
func RequireRole(roles ...models.Role) gin.HandlerFunc {
	return func(c *gin.Context) {
		userRole := models.Role(c.GetString("userRole"))

		for _, role := range roles {
			if userRole == role {
				c.Next()
				return
			}
		}

		c.AbortWithStatusJSON(http.StatusForbidden, response.ErrorResponse{
			Error: "Insufficient role",
			Code:  "FORBIDDEN",
		})
	}
}

// RequireAdmin checks if user is admin
func RequireAdmin() gin.HandlerFunc {
	return RequireRole(models.RoleAdmin)
}

// DataScopeMiddleware determines what data the user can access
func DataScopeMiddleware(resource models.Resource) gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.GetString("userRole")
		flatID := c.GetString("userFlatID")
		userID := c.GetString("userID")

		// Admin sees all
		if role == string(models.RoleAdmin) {
			c.Set("dataScope", ScopeAll)
			c.Next()
			return
		}

		// Check if member has read_all permission for this resource
		permissions, exists := c.Get("userPermissions")
		if exists {
			readAllPerm := string(resource) + ":read_all"
			permList := permissions.([]string)

			for _, p := range permList {
				if p == readAllPerm {
					c.Set("dataScope", ScopeAll)
					c.Next()
					return
				}
			}
		}

		// Default to own data only
		c.Set("dataScope", ScopeOwn)
		c.Set("filterFlatID", flatID)
		c.Set("filterUserID", userID)

		c.Next()
	}
}

// GetDataScope returns the current data scope from context
func GetDataScope(c *gin.Context) DataScope {
	scope, exists := c.Get("dataScope")
	if !exists {
		return ScopeOwn
	}
	return scope.(DataScope)
}

// GetFilterFlatID returns the flat ID filter from context
func GetFilterFlatID(c *gin.Context) string {
	return c.GetString("filterFlatID")
}

// GetFilterUserID returns the user ID filter from context
func GetFilterUserID(c *gin.Context) string {
	return c.GetString("filterUserID")
}

// IsAdmin checks if current user is admin
func IsAdmin(c *gin.Context) bool {
	return c.GetString("userRole") == string(models.RoleAdmin)
}

// CanAccessResource checks if user can perform action on resource
func CanAccessResource(c *gin.Context, resource models.Resource, action models.Action) bool {
	if IsAdmin(c) {
		return true
	}

	permissions, exists := c.Get("userPermissions")
	if !exists {
		return false
	}

	required := string(resource) + ":" + string(action)
	permList := permissions.([]string)

	for _, p := range permList {
		if p == required {
			return true
		}
	}

	return false
}
