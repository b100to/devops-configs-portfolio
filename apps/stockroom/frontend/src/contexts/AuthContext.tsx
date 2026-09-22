import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import { User, LoginResponse } from '../types/api';
import { getMe } from '../services/api';

interface AuthContextType {
    user: User | null;
    isAdmin: boolean;
    token: string | null;
    loading: boolean;
    needsProfileCompletion: boolean;
    login: (response: LoginResponse) => void;
    logout: () => void;
    refreshUser: () => Promise<void>;
    completeProfile: () => void;
}

const AuthContext = createContext<AuthContextType | null>(null);

export const useAuth = () => {
    const context = useContext(AuthContext);
    if (!context) {
        throw new Error('useAuth must be used within an AuthProvider');
    }
    return context;
};

export const AuthProvider = ({ children }: { children: ReactNode }) => {
    const [user, setUser] = useState<User | null>(null);
    const [isAdmin, setIsAdmin] = useState(false);
    const [token, setToken] = useState<string | null>(localStorage.getItem('token'));
    const [loading, setLoading] = useState(!!localStorage.getItem('token'));
    const [needsProfileCompletion, setNeedsProfileCompletion] = useState(false);

    const login = useCallback((response: LoginResponse) => {
        setUser(response.user);
        setIsAdmin(response.is_admin);
        setToken(response.token);
        if (response.token) {
            localStorage.setItem('token', response.token);
        }
        // team_name이 비어있으면 프로필 보완 필요
        if (!response.user.team_name) {
            setNeedsProfileCompletion(true);
        }
    }, []);

    const logout = useCallback(() => {
        setUser(null);
        setIsAdmin(false);
        setToken(null);
        setNeedsProfileCompletion(false);
        localStorage.removeItem('token');
    }, []);

    const completeProfile = useCallback(() => {
        setNeedsProfileCompletion(false);
    }, []);

    const refreshUser = useCallback(async () => {
        const savedToken = localStorage.getItem('token');
        if (!savedToken) {
            setLoading(false);
            return;
        }

        try {
            const response = await getMe();
            setUser(response.user);
            setIsAdmin(response.is_admin);
            if (!response.user.team_name) {
                setNeedsProfileCompletion(true);
            }
        } catch {
            localStorage.removeItem('token');
            setToken(null);
        } finally {
            setLoading(false);
        }
    }, []);

    // 앱 시작 시 저장된 토큰으로 세션 복원
    useEffect(() => {
        if (token && !user) {
            refreshUser();
        } else {
            setLoading(false);
        }
    }, []); // eslint-disable-line react-hooks/exhaustive-deps

    return (
        <AuthContext.Provider value={{ user, isAdmin, token, loading, needsProfileCompletion, login, logout, refreshUser, completeProfile }}>
            {children}
        </AuthContext.Provider>
    );
};
