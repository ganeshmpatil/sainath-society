import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import { authApi } from '../api/auth';
import { apiClient } from '../api/client';
import type { User, LoginRequest } from '../types/auth';

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  isAdmin: boolean;
  login: (credentials: LoginRequest) => Promise<void>;
  logout: () => Promise<void>;
  hasPermission: (resource: string, action: string) => boolean;
  canAccessOwn: (resource: string) => boolean;
  canAccessAll: (resource: string) => boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
  children: ReactNode;
}

export function AuthProvider({ children }: AuthProviderProps) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const isAuthenticated = !!user;
  const isAdmin = user?.role === 'ADMIN';

  // Check for existing session on mount
  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem('accessToken');
      if (token) {
        apiClient.setAccessToken(token);
        try {
          const userData = await authApi.getMe();
          setUser(userData);
        } catch {
          apiClient.setAccessToken(null);
        }
      }
      setIsLoading(false);
    };

    checkAuth();
  }, []);

  const login = useCallback(async (credentials: LoginRequest) => {
    const response = await authApi.login(credentials);
    setUser(response.user);
  }, []);

  const logout = useCallback(async () => {
    try {
      await authApi.logout();
    } finally {
      setUser(null);
    }
  }, []);

  const hasPermission = useCallback(
    (resource: string, action: string): boolean => {
      if (!user) return false;
      if (isAdmin) return true;
      return user.permissions.includes(`${resource}:${action}`);
    },
    [user, isAdmin]
  );

  const canAccessOwn = useCallback(
    (resource: string): boolean => {
      return hasPermission(resource, 'read_own') || hasPermission(resource, 'read_all');
    },
    [hasPermission]
  );

  const canAccessAll = useCallback(
    (resource: string): boolean => {
      return isAdmin || hasPermission(resource, 'read_all');
    },
    [isAdmin, hasPermission]
  );

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated,
        isLoading,
        isAdmin,
        login,
        logout,
        hasPermission,
        canAccessOwn,
        canAccessAll,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
