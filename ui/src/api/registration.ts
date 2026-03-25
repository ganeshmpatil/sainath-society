import { apiClient } from './client';

export interface MemberInfo {
  id: string;
  name: string;
  mobile: string;
  flatNumber?: string;
  wing?: string;
  role: string;
  designation?: string;
}

export interface InitiateResponse {
  message: string;
  member: MemberInfo;
  otpExpiry: number;
}

export interface VerifyOTPResponse {
  message: string;
  verified: boolean;
}

export interface RegistrationCompleteResponse {
  message: string;
  user: {
    id: string;
    name: string;
    email: string;
    phone: string;
    role: string;
  };
}

export const registrationApi = {
  initiate: async (mobile: string): Promise<InitiateResponse> => {
    return apiClient.post<InitiateResponse>('/registration/initiate', { mobile }, {
      skipAuth: true,
    });
  },

  verifyOTP: async (mobile: string, otp: string): Promise<VerifyOTPResponse> => {
    return apiClient.post<VerifyOTPResponse>('/registration/verify-otp', { mobile, otp }, {
      skipAuth: true,
    });
  },

  complete: async (mobile: string, email: string, password: string): Promise<RegistrationCompleteResponse> => {
    return apiClient.post<RegistrationCompleteResponse>('/registration/complete', {
      mobile,
      email,
      password,
    }, {
      skipAuth: true,
    });
  },

  resendOTP: async (mobile: string): Promise<{ message: string }> => {
    return apiClient.post<{ message: string }>('/registration/resend-otp', { mobile }, {
      skipAuth: true,
    });
  },
};
