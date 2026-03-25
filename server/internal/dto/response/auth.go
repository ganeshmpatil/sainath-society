package response

import "time"

// UserResponse represents user data in API response
type UserResponse struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Email       string   `json:"email"`
	Phone       string   `json:"phone"`
	Role        string   `json:"role"`
	Designation string   `json:"designation,omitempty"`
	FlatID      string   `json:"flatId,omitempty"`
	FlatNumber  string   `json:"flatNumber,omitempty"`
	Permissions []string `json:"permissions"`
	IsActive    bool     `json:"isActive"`
}

// LoginResponse represents successful login response
type LoginResponse struct {
	AccessToken string       `json:"accessToken"`
	ExpiresIn   int          `json:"expiresIn"`
	ExpiresAt   time.Time    `json:"expiresAt"`
	User        UserResponse `json:"user"`
}

// RefreshResponse represents token refresh response
type RefreshResponse struct {
	AccessToken string    `json:"accessToken"`
	ExpiresIn   int       `json:"expiresIn"`
	ExpiresAt   time.Time `json:"expiresAt"`
}

// ErrorResponse represents error response
type ErrorResponse struct {
	Error   string `json:"error"`
	Code    string `json:"code,omitempty"`
	Details string `json:"details,omitempty"`
}

// MessageResponse represents simple message response
type MessageResponse struct {
	Message string `json:"message"`
}
