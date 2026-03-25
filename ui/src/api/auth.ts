import { apiClient } from './client';
import type { LoginRequest, LoginResponse, RefreshResponse, User } from '../types/auth';

export const authApi = {
  login: async (credentials: LoginRequest): Promise<LoginResponse> => {
    const response = await apiClient.post<LoginResponse>('/auth/login', credentials, {
      skipAuth: true,
    });
    apiClient.setAccessToken(response.accessToken);
    return response;
  },

  logout: async (): Promise<void> => {
    try {
      await apiClient.post('/auth/logout');
    } finally {
      apiClient.setAccessToken(null);
    }
  },

  refresh: async (): Promise<RefreshResponse> => {
    return apiClient.post<RefreshResponse>('/auth/refresh', undefined, {
      skipAuth: true,
    });
  },

  getMe: async (): Promise<User> => {
    return apiClient.get<User>('/auth/me');
  },
};
