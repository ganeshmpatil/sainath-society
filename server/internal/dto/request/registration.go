package request

// InitiateRegistrationRequest starts the registration process
type InitiateRegistrationRequest struct {
	Mobile string `json:"mobile" binding:"required,min=10,max=15"`
}

// VerifyOTPRequest verifies OTP
type VerifyOTPRequest struct {
	Mobile string `json:"mobile" binding:"required,min=10,max=15"`
	OTP    string `json:"otp" binding:"required,len=6"`
}

// CompleteRegistrationRequest completes registration with credentials
type CompleteRegistrationRequest struct {
	Mobile   string `json:"mobile" binding:"required,min=10,max=15"`
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
}

// ResendOTPRequest requests a new OTP
type ResendOTPRequest struct {
	Mobile string `json:"mobile" binding:"required,min=10,max=15"`
}
