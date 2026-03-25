export type Role = 'MEMBER' | 'ADMIN';

export interface User {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: Role;
  designation?: string;
  flatId?: string;
  flatNumber?: string;
  permissions: string[];
  isActive: boolean;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  accessToken: string;
  expiresIn: number;
  expiresAt: string;
  user: User;
}

export interface RefreshResponse {
  accessToken: string;
  expiresIn: number;
  expiresAt: string;
}

export interface ErrorResponse {
  error: string;
  code?: string;
  details?: string;
}
