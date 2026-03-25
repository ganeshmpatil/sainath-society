# Login & RBAC Technical Design

## 1. Overview

### Requirements
- **107 users total**: 100 Members + 7 Admins
- **2 Roles**: `MEMBER` and `ADMIN`
- **Data Access**:
  - Members see **only their own data** on certain screens
  - Members see **all data** on certain screens (read-only)
  - Admins see **all data** on all screens with full CRUD

### Access Matrix

| Screen | Member Access | Admin Access |
|--------|---------------|--------------|
| Dashboard | Own stats + Society summary | Full stats |
| My Flat | Own flat only | All flats |
| Resident Directory | View all (read-only) | Full CRUD |
| Grievances | Own grievances | All grievances |
| Notices | View all | Full CRUD |
| Finance | Own bills/payments | All finance |
| Vehicles | Own vehicles | All vehicles |
| Polls | Vote only | Create + Manage |
| Meetings | View + RSVP | Full CRUD |
| Hall Booking | Own bookings | All bookings |
| Pending Tasks | - | Full access |
| Inventory | View only | Full CRUD |
| Bylaws | View only | Full CRUD |
| User Management | - | Full access |

---

## 2. Database Design

### Users Table

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(15) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,

    -- Profile
    name VARCHAR(100) NOT NULL,
    flat_id UUID REFERENCES flats(id),

    -- Role & Status
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER',  -- 'MEMBER' | 'ADMIN'
    designation VARCHAR(50),  -- 'Chairman', 'Secretary', 'Treasurer', etc.
    is_active BOOLEAN DEFAULT true,

    -- Security
    failed_login_attempts INT DEFAULT 0,
    locked_until TIMESTAMP,
    password_changed_at TIMESTAMP,
    must_change_password BOOLEAN DEFAULT false,

    -- Tokens
    refresh_token_hash VARCHAR(255),
    refresh_token_expires_at TIMESTAMP,

    -- Audit
    last_login_at TIMESTAMP,
    last_login_ip VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),

    CONSTRAINT valid_role CHECK (role IN ('MEMBER', 'ADMIN'))
);

-- Indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_flat ON users(flat_id);
CREATE INDEX idx_users_role ON users(role);
```

### Permissions Table (For Fine-Grained Control)

```sql
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource VARCHAR(50) NOT NULL,   -- 'grievances', 'finance', 'notices'
    action VARCHAR(20) NOT NULL,     -- 'create', 'read', 'update', 'delete', 'read_own'

    UNIQUE(resource, action)
);

CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role VARCHAR(20) NOT NULL,
    permission_id UUID REFERENCES permissions(id),

    UNIQUE(role, permission_id)
);
```

### Seed Data

```sql
-- Insert permissions
INSERT INTO permissions (resource, action) VALUES
-- Grievances
('grievances', 'create'),
('grievances', 'read_own'),
('grievances', 'read_all'),
('grievances', 'update'),
('grievances', 'delete'),
-- Finance
('finance', 'read_own'),
('finance', 'read_all'),
('finance', 'create'),
('finance', 'update'),
-- Notices
('notices', 'read_all'),
('notices', 'create'),
('notices', 'update'),
('notices', 'delete'),
-- ... more resources

-- Assign permissions to MEMBER role
INSERT INTO role_permissions (role, permission_id)
SELECT 'MEMBER', id FROM permissions
WHERE (resource, action) IN (
    ('grievances', 'create'),
    ('grievances', 'read_own'),
    ('finance', 'read_own'),
    ('notices', 'read_all'),
    ('vehicles', 'read_own'),
    ('vehicles', 'create'),
    ('polls', 'vote'),
    ('meetings', 'read_all'),
    ('hall_booking', 'create'),
    ('hall_booking', 'read_own')
);

-- Assign ALL permissions to ADMIN role
INSERT INTO role_permissions (role, permission_id)
SELECT 'ADMIN', id FROM permissions;
```

---

## 3. Authentication Flow

### Login Sequence

```
┌──────────┐         ┌──────────┐         ┌──────────┐         ┌──────────┐
│  Client  │         │   Kong   │         │ Auth API │         │ Postgres │
└────┬─────┘         └────┬─────┘         └────┬─────┘         └────┬─────┘
     │                    │                    │                    │
     │ POST /api/v1/auth/login                 │                    │
     │ {email, password}  │                    │                    │
     │───────────────────>│                    │                    │
     │                    │                    │                    │
     │                    │ Forward request    │                    │
     │                    │───────────────────>│                    │
     │                    │                    │                    │
     │                    │                    │ Find user by email │
     │                    │                    │───────────────────>│
     │                    │                    │                    │
     │                    │                    │<───────────────────│
     │                    │                    │                    │
     │                    │                    │ Verify password    │
     │                    │                    │ Check account lock │
     │                    │                    │ Load permissions   │
     │                    │                    │                    │
     │                    │                    │ Generate tokens    │
     │                    │                    │ - Access (15min)   │
     │                    │                    │ - Refresh (7 days) │
     │                    │                    │                    │
     │                    │                    │ Update last_login  │
     │                    │                    │───────────────────>│
     │                    │                    │                    │
     │                    │<───────────────────│                    │
     │                    │                    │                    │
     │<───────────────────│                    │                    │
     │                    │                    │                    │
     │ Response:          │                    │                    │
     │ {                  │                    │                    │
     │   accessToken,     │                    │                    │
     │   user: {          │                    │                    │
     │     id, name,      │                    │                    │
     │     role,          │                    │                    │
     │     flatId,        │                    │                    │
     │     permissions[]  │                    │                    │
     │   }                │                    │                    │
     │ }                  │                    │                    │
     │ + Set-Cookie:      │                    │                    │
     │   refreshToken     │                    │                    │
     │   (httpOnly)       │                    │                    │
```

### JWT Token Structure

```json
// Access Token Payload
{
  "sub": "user-uuid",
  "email": "user@email.com",
  "role": "MEMBER",
  "flatId": "flat-uuid",
  "permissions": [
    "grievances:create",
    "grievances:read_own",
    "finance:read_own",
    "notices:read_all"
  ],
  "iat": 1679900000,
  "exp": 1679900900  // 15 min
}
```

### Token Refresh Flow

```
Client                    Kong                     Auth API
   │                        │                          │
   │ GET /api/v1/finance    │                          │
   │ (expired access token) │                          │
   │───────────────────────>│                          │
   │                        │                          │
   │<───────────────────────│                          │
   │ 401 Unauthorized       │                          │
   │                        │                          │
   │ POST /api/v1/auth/refresh                         │
   │ Cookie: refreshToken   │                          │
   │───────────────────────>│                          │
   │                        │─────────────────────────>│
   │                        │                          │
   │                        │<─────────────────────────│
   │<───────────────────────│                          │
   │ { newAccessToken }     │                          │
   │                        │                          │
   │ Retry original request │                          │
   │ with new access token  │                          │
```

---

## 4. Backend Implementation

### Project Structure

```
backend/
├── internal/
│   ├── auth/
│   │   ├── handler.go       # HTTP handlers
│   │   ├── service.go       # Business logic
│   │   ├── repository.go    # Database queries
│   │   └── middleware.go    # Auth middleware
│   ├── rbac/
│   │   ├── permissions.go   # Permission constants
│   │   ├── checker.go       # Permission checker
│   │   └── middleware.go    # RBAC middleware
│   └── ...
```

### Permission Constants (Go)

```go
// internal/rbac/permissions.go
package rbac

type Permission string
type Resource string
type Action string

const (
    // Resources
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
)

const (
    // Actions
    ActionCreate  Action = "create"
    ActionReadOwn Action = "read_own"
    ActionReadAll Action = "read_all"
    ActionUpdate  Action = "update"
    ActionDelete  Action = "delete"
)

// Role definitions
type Role string

const (
    RoleMember Role = "MEMBER"
    RoleAdmin  Role = "ADMIN"
)

// Permission map
var RolePermissions = map[Role][]Permission{
    RoleMember: {
        "grievances:create",
        "grievances:read_own",
        "finance:read_own",
        "vehicles:create",
        "vehicles:read_own",
        "vehicles:update",
        "vehicles:delete",  // own only
        "notices:read_all",
        "polls:vote",
        "meetings:read_all",
        "hall_booking:create",
        "hall_booking:read_own",
        "residents:read_all",
        "bylaws:read_all",
        "inventory:read_all",
    },
    RoleAdmin: {
        "*:*",  // Full access
    },
}
```

### Auth Middleware

```go
// internal/auth/middleware.go
package auth

import (
    "net/http"
    "strings"

    "github.com/gin-gonic/gin"
    "github.com/golang-jwt/jwt/v5"
)

type Claims struct {
    UserID      string   `json:"sub"`
    Email       string   `json:"email"`
    Role        string   `json:"role"`
    FlatID      string   `json:"flatId"`
    Permissions []string `json:"permissions"`
    jwt.RegisteredClaims
}

func AuthMiddleware(jwtSecret string) gin.HandlerFunc {
    return func(c *gin.Context) {
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
                "error": "Missing authorization header",
            })
            return
        }

        tokenString := strings.TrimPrefix(authHeader, "Bearer ")

        claims := &Claims{}
        token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
            return []byte(jwtSecret), nil
        })

        if err != nil || !token.Valid {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
                "error": "Invalid or expired token",
            })
            return
        }

        // Set user context
        c.Set("userID", claims.UserID)
        c.Set("userRole", claims.Role)
        c.Set("userFlatID", claims.FlatID)
        c.Set("userPermissions", claims.Permissions)

        c.Next()
    }
}
```

### RBAC Middleware

```go
// internal/rbac/middleware.go
package rbac

import (
    "net/http"

    "github.com/gin-gonic/gin"
)

// RequirePermission checks if user has required permission
func RequirePermission(resource Resource, action Action) gin.HandlerFunc {
    return func(c *gin.Context) {
        role := c.GetString("userRole")
        permissions := c.GetStringSlice("userPermissions")

        // Admin has full access
        if role == string(RoleAdmin) {
            c.Next()
            return
        }

        required := string(resource) + ":" + string(action)

        for _, p := range permissions {
            if p == required {
                c.Next()
                return
            }
        }

        c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
            "error": "Permission denied",
            "required": required,
        })
    }
}

// RequireRole checks if user has required role
func RequireRole(roles ...Role) gin.HandlerFunc {
    return func(c *gin.Context) {
        userRole := Role(c.GetString("userRole"))

        for _, role := range roles {
            if userRole == role {
                c.Next()
                return
            }
        }

        c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
            "error": "Insufficient role",
        })
    }
}
```

### Data Filter Middleware

```go
// internal/rbac/data_filter.go
package rbac

import "github.com/gin-gonic/gin"

type DataScope string

const (
    ScopeOwn DataScope = "own"
    ScopeAll DataScope = "all"
)

// DataScopeMiddleware determines what data the user can access
func DataScopeMiddleware(resource Resource) gin.HandlerFunc {
    return func(c *gin.Context) {
        role := c.GetString("userRole")
        flatID := c.GetString("userFlatID")
        userID := c.GetString("userID")

        // Admin sees all
        if role == string(RoleAdmin) {
            c.Set("dataScope", ScopeAll)
            c.Next()
            return
        }

        // Check if member has read_all permission for this resource
        permissions := c.GetStringSlice("userPermissions")
        readAllPerm := string(resource) + ":read_all"

        for _, p := range permissions {
            if p == readAllPerm {
                c.Set("dataScope", ScopeAll)
                c.Next()
                return
            }
        }

        // Default to own data only
        c.Set("dataScope", ScopeOwn)
        c.Set("filterFlatID", flatID)
        c.Set("filterUserID", userID)

        c.Next()
    }
}
```

### Using Middleware in Routes

```go
// internal/routes/routes.go
package routes

import (
    "github.com/gin-gonic/gin"

    "society/internal/auth"
    "society/internal/rbac"
    "society/internal/handlers"
)

func SetupRoutes(r *gin.Engine, cfg *config.Config) {
    api := r.Group("/api/v1")

    // Public routes
    api.POST("/auth/login", handlers.Login)
    api.POST("/auth/refresh", handlers.RefreshToken)

    // Protected routes
    protected := api.Group("")
    protected.Use(auth.AuthMiddleware(cfg.JWTSecret))

    // Grievances - Members see own, Admin sees all
    grievances := protected.Group("/grievances")
    grievances.Use(rbac.DataScopeMiddleware(rbac.ResourceGrievances))
    {
        grievances.GET("", handlers.ListGrievances)
        grievances.POST("",
            rbac.RequirePermission(rbac.ResourceGrievances, rbac.ActionCreate),
            handlers.CreateGrievance)
        grievances.PUT("/:id",
            rbac.RequirePermission(rbac.ResourceGrievances, rbac.ActionUpdate),
            handlers.UpdateGrievance)
    }

    // Finance - Members see own, Admin sees all
    finance := protected.Group("/finance")
    finance.Use(rbac.DataScopeMiddleware(rbac.ResourceFinance))
    {
        finance.GET("/bills", handlers.ListBills)
        finance.GET("/payments", handlers.ListPayments)
        finance.POST("/payments",
            rbac.RequireRole(rbac.RoleAdmin),
            handlers.RecordPayment)
    }

    // Notices - Everyone reads, Admin manages
    notices := protected.Group("/notices")
    {
        notices.GET("", handlers.ListNotices)  // All can read
        notices.POST("",
            rbac.RequireRole(rbac.RoleAdmin),
            handlers.CreateNotice)
        notices.PUT("/:id",
            rbac.RequireRole(rbac.RoleAdmin),
            handlers.UpdateNotice)
        notices.DELETE("/:id",
            rbac.RequireRole(rbac.RoleAdmin),
            handlers.DeleteNotice)
    }

    // Admin only routes
    admin := protected.Group("/admin")
    admin.Use(rbac.RequireRole(rbac.RoleAdmin))
    {
        admin.GET("/users", handlers.ListUsers)
        admin.POST("/users", handlers.CreateUser)
        admin.PUT("/users/:id", handlers.UpdateUser)
        admin.DELETE("/users/:id", handlers.DeactivateUser)
        admin.GET("/pending-tasks", handlers.ListPendingTasks)
    }
}
```

### Handler with Data Filtering

```go
// internal/handlers/grievances.go
package handlers

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "society/internal/rbac"
)

func ListGrievances(c *gin.Context) {
    scope := c.GetString("dataScope")

    var grievances []Grievance
    var err error

    if scope == string(rbac.ScopeAll) {
        // Admin or has read_all permission - fetch all
        grievances, err = grievanceService.FindAll(c.Request.Context())
    } else {
        // Member - fetch only their flat's grievances
        flatID := c.GetString("filterFlatID")
        grievances, err = grievanceService.FindByFlatID(c.Request.Context(), flatID)
    }

    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "data": grievances,
        "meta": gin.H{
            "scope": scope,
            "total": len(grievances),
        },
    })
}
```

---

## 5. Frontend Implementation

### Auth Context

```typescript
// src/context/AuthContext.tsx
import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { authApi } from '@/api/auth.api';

interface User {
  id: string;
  name: string;
  email: string;
  role: 'MEMBER' | 'ADMIN';
  flatId: string;
  flatNumber: string;
  permissions: string[];
}

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isAdmin: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  hasPermission: (resource: string, action: string) => boolean;
  canAccessOwn: (resource: string) => boolean;
  canAccessAll: (resource: string) => boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [accessToken, setAccessToken] = useState<string | null>(null);

  const isAuthenticated = !!user;
  const isAdmin = user?.role === 'ADMIN';

  const hasPermission = (resource: string, action: string): boolean => {
    if (!user) return false;
    if (isAdmin) return true;
    return user.permissions.includes(`${resource}:${action}`);
  };

  const canAccessOwn = (resource: string): boolean => {
    return hasPermission(resource, 'read_own') || hasPermission(resource, 'read_all');
  };

  const canAccessAll = (resource: string): boolean => {
    return isAdmin || hasPermission(resource, 'read_all');
  };

  const login = async (email: string, password: string) => {
    const response = await authApi.login({ email, password });
    setAccessToken(response.accessToken);
    setUser(response.user);
    localStorage.setItem('accessToken', response.accessToken);
  };

  const logout = () => {
    setUser(null);
    setAccessToken(null);
    localStorage.removeItem('accessToken');
    authApi.logout();
  };

  // Check for existing session on mount
  useEffect(() => {
    const token = localStorage.getItem('accessToken');
    if (token) {
      authApi.getMe()
        .then(setUser)
        .catch(() => localStorage.removeItem('accessToken'));
    }
  }, []);

  return (
    <AuthContext.Provider value={{
      user,
      isAuthenticated,
      isAdmin,
      login,
      logout,
      hasPermission,
      canAccessOwn,
      canAccessAll,
    }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
};
```

### Permission-Based Component

```typescript
// src/components/PermissionGate.tsx
import { ReactNode } from 'react';
import { useAuth } from '@/context/AuthContext';

interface PermissionGateProps {
  resource: string;
  action: string;
  children: ReactNode;
  fallback?: ReactNode;
}

export function PermissionGate({
  resource,
  action,
  children,
  fallback = null
}: PermissionGateProps) {
  const { hasPermission } = useAuth();

  if (!hasPermission(resource, action)) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
}

// Usage:
// <PermissionGate resource="notices" action="create">
//   <Button>Create Notice</Button>
// </PermissionGate>
```

### Role-Based Route Guard

```typescript
// src/components/ProtectedRoute.tsx
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '@/context/AuthContext';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredRole?: 'MEMBER' | 'ADMIN';
  requiredPermission?: { resource: string; action: string };
}

export function ProtectedRoute({
  children,
  requiredRole,
  requiredPermission
}: ProtectedRouteProps) {
  const { isAuthenticated, user, hasPermission } = useAuth();
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  if (requiredRole && user?.role !== requiredRole && user?.role !== 'ADMIN') {
    return <Navigate to="/unauthorized" replace />;
  }

  if (requiredPermission && !hasPermission(requiredPermission.resource, requiredPermission.action)) {
    return <Navigate to="/unauthorized" replace />;
  }

  return <>{children}</>;
}
```

### Dynamic Menu Based on Role

```typescript
// src/components/Layout.tsx
import { useAuth } from '@/context/AuthContext';

const allMenuItems = [
  { path: '/', icon: Home, label: 'Dashboard', permissions: null }, // Everyone
  { path: '/my-flat', icon: Building2, label: 'My Flat', permissions: null },
  { path: '/residents', icon: Users, label: 'Residents', permissions: { resource: 'residents', action: 'read_all' } },
  { path: '/grievances', icon: MessageSquare, label: 'Grievances', permissions: null }, // Filtered by backend
  { path: '/notices', icon: Bell, label: 'Notices', permissions: null },
  { path: '/finance', icon: DollarSign, label: 'Finance', permissions: null }, // Filtered by backend
  { path: '/vehicles', icon: Car, label: 'Vehicles', permissions: null },
  { path: '/polls', icon: Vote, label: 'Polls', permissions: null },
  { path: '/meetings', icon: Calendar, label: 'Meetings', permissions: null },
  { path: '/hall-booking', icon: CalendarDays, label: 'Hall Booking', permissions: null },
  { path: '/inventory', icon: Package, label: 'Inventory', permissions: { resource: 'inventory', action: 'read_all' } },
  { path: '/bylaws', icon: BookOpen, label: 'Bylaws', permissions: null },
  // Admin only
  { path: '/pending-tasks', icon: CheckSquare, label: 'Pending Tasks', adminOnly: true },
  { path: '/admin/users', icon: Users, label: 'User Management', adminOnly: true },
  { path: '/admin/flats', icon: Building2, label: 'All Flats', adminOnly: true },
];

export function Layout({ children }) {
  const { isAdmin, hasPermission } = useAuth();

  const visibleMenuItems = allMenuItems.filter(item => {
    if (item.adminOnly && !isAdmin) return false;
    if (item.permissions && !hasPermission(item.permissions.resource, item.permissions.action)) {
      return false;
    }
    return true;
  });

  return (
    <div>
      <Sidebar items={visibleMenuItems} />
      <main>{children}</main>
    </div>
  );
}
```

### Data Display with Scope Awareness

```typescript
// src/pages/Grievances.tsx
import { useAuth } from '@/context/AuthContext';
import { useGrievances } from '@/hooks/useGrievances';

export default function Grievances() {
  const { isAdmin, canAccessAll, user } = useAuth();
  const { data: grievances, isLoading } = useGrievances();

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1>Grievances</h1>
          {!canAccessAll('grievances') && (
            <p className="text-sm text-slate-400">
              Showing grievances for flat {user?.flatNumber}
            </p>
          )}
        </div>

        {/* All members can create grievances */}
        <Button onClick={() => setShowCreateModal(true)}>
          Raise Grievance
        </Button>
      </div>

      <GrievanceTable
        data={grievances}
        showFlatColumn={canAccessAll('grievances')}
        showActions={isAdmin}
      />
    </div>
  );
}
```

---

## 6. API Endpoints

### Auth Endpoints

```
POST   /api/v1/auth/login          # Login with email/password
POST   /api/v1/auth/refresh        # Refresh access token
POST   /api/v1/auth/logout         # Invalidate refresh token
GET    /api/v1/auth/me             # Get current user with permissions
PUT    /api/v1/auth/password       # Change password
POST   /api/v1/auth/forgot         # Forgot password (future)
POST   /api/v1/auth/reset          # Reset password (future)
```

### Request/Response Examples

```json
// POST /api/v1/auth/login
// Request
{
  "email": "rajesh@email.com",
  "password": "securepassword"
}

// Response 200
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 900,
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Rajesh Kumar",
    "email": "rajesh@email.com",
    "role": "ADMIN",
    "flatId": "flat-uuid",
    "flatNumber": "A-101",
    "designation": "Chairman",
    "permissions": [
      "grievances:create",
      "grievances:read_all",
      "grievances:update",
      "grievances:delete",
      "finance:read_all",
      "finance:create",
      // ... all permissions for admin
    ]
  }
}

// Response 401 (Invalid credentials)
{
  "error": "Invalid email or password",
  "code": "INVALID_CREDENTIALS"
}

// Response 423 (Account locked)
{
  "error": "Account locked due to too many failed attempts",
  "code": "ACCOUNT_LOCKED",
  "lockedUntil": "2024-03-01T10:30:00Z"
}
```

---

## 7. Login Screen Flow

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    SAINATH SOCIETY                          │
│                    ─────────────────                        │
│                                                             │
│                  ┌─────────────────────┐                    │
│                  │                     │                    │
│                  │   Email / Phone     │                    │
│                  │                     │                    │
│                  └─────────────────────┘                    │
│                                                             │
│                  ┌─────────────────────┐                    │
│                  │                     │                    │
│                  │   Password      👁  │                    │
│                  │                     │                    │
│                  └─────────────────────┘                    │
│                                                             │
│                  ☐ Remember me    Forgot Password?          │
│                                                             │
│                  ┌─────────────────────┐                    │
│                  │                     │                    │
│                  │      LOGIN          │                    │
│                  │                     │                    │
│                  └─────────────────────┘                    │
│                                                             │
│                  ─────────────────────────                  │
│                                                             │
│                  Need help? Contact admin                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
              ┌─────────────────────────────┐
              │     Validate Credentials    │
              └─────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
        ┌───────────┐              ┌───────────┐
        │   ADMIN   │              │  MEMBER   │
        └─────┬─────┘              └─────┬─────┘
              │                          │
              ▼                          ▼
    ┌─────────────────┐        ┌─────────────────┐
    │ Admin Dashboard │        │ Member Dashboard│
    │                 │        │                 │
    │ - All society   │        │ - Own flat info │
    │   statistics    │        │ - Own dues      │
    │ - Pending tasks │        │ - Society news  │
    │ - All grievances│        │ - Own grievances│
    │ - User mgmt     │        │                 │
    └─────────────────┘        └─────────────────┘
```

---

## 8. Security Considerations

### Password Security
- Bcrypt with cost factor 12
- Minimum 8 characters
- Must include: uppercase, lowercase, number

### Account Protection
- Lock account after 5 failed attempts
- Lockout duration: 30 minutes
- Rate limit login: 10 attempts/minute per IP

### Token Security
- Access token: 15 minutes
- Refresh token: 7 days, httpOnly cookie
- Refresh token rotation on use
- Invalidate all tokens on password change

### Session Management
- Single session per user (optional)
- Track active sessions
- Allow user to view and revoke sessions

---

## 9. Implementation Checklist

### Day 1 Tasks
- [ ] Database: Create users table with migrations
- [ ] Backend: Login endpoint with JWT generation
- [ ] Backend: Auth middleware
- [ ] Backend: RBAC middleware
- [ ] Frontend: Login page UI
- [ ] Frontend: Auth context
- [ ] Frontend: Protected routes
- [ ] Frontend: Dynamic sidebar
- [ ] Integration: Test login flow
- [ ] Seed: Create 7 admin + 100 member users

---

## 10. Sample Seed Data

```sql
-- Admin users (committee members)
INSERT INTO users (email, phone, password_hash, name, role, designation) VALUES
('chairman@sainath.com', '9876543210', '$2a$12$...', 'Rajesh Kumar', 'ADMIN', 'Chairman'),
('secretary@sainath.com', '9876543211', '$2a$12$...', 'Priya Sharma', 'ADMIN', 'Secretary'),
('treasurer@sainath.com', '9876543212', '$2a$12$...', 'Amit Patel', 'ADMIN', 'Treasurer'),
('member1@sainath.com', '9876543213', '$2a$12$...', 'Vikram Singh', 'ADMIN', 'Committee Member'),
('member2@sainath.com', '9876543214', '$2a$12$...', 'Meera Joshi', 'ADMIN', 'Committee Member'),
('member3@sainath.com', '9876543215', '$2a$12$...', 'Karan Mehta', 'ADMIN', 'Committee Member'),
('member4@sainath.com', '9876543216', '$2a$12$...', 'Anjali Reddy', 'ADMIN', 'Committee Member');

-- Regular members (100 users for flats A-101 to C-310)
-- Generated programmatically
```
