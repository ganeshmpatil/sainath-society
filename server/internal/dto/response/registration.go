package response

// MemberInfoResponse contains member info for registration
type MemberInfoResponse struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Mobile      string `json:"mobile"`
	FlatNumber  string `json:"flatNumber,omitempty"`
	Wing        string `json:"wing,omitempty"`
	Role        string `json:"role"`
	Designation string `json:"designation,omitempty"`
}

// InitiateRegistrationResponse after OTP is sent
type InitiateRegistrationResponse struct {
	Message    string             `json:"message"`
	Member     MemberInfoResponse `json:"member"`
	OTPExpiry  int                `json:"otpExpiry"` // seconds
}

// VerifyOTPResponse after successful OTP verification
type VerifyOTPResponse struct {
	Message string `json:"message"`
	Verified bool   `json:"verified"`
}

// RegistrationCompleteResponse after successful registration
type RegistrationCompleteResponse struct {
	Message string       `json:"message"`
	User    UserResponse `json:"user"`
}
