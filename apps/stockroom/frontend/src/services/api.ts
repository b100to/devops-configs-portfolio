import axios from 'axios';
import {
    User,
    Organization,
    OrganizationType,
    Item,
    Category,
    Request,
    RegisterRequest,
    LoginRequest,
    LoginResponse,
    GoogleLoginRequest,
    CreateOrganizationRequest,
    UpdateOrganizationRequest,
    CreateRequestData,
    CreateItemData,
    UpdateItemData,
    UpdateProfileData,
    UpdateUserByAdminData
} from '../types/api';

// Production: empty string (same origin), Development: localhost:8080
const API_BASE_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:8080';

const api = axios.create({
    baseURL: API_BASE_URL,
    headers: {
        'Content-Type': 'application/json',
    },
});

// 요청 인터셉터: JWT 토큰 자동 추가
api.interceptors.request.use((config) => {
    const token = localStorage.getItem('token');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

// 응답 인터셉터: 에러 처리 + 401 시 토큰 삭제
api.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response?.status === 401) {
            localStorage.removeItem('token');
        }
        if (error.response?.data?.error) {
            throw new Error(error.response.data.error);
        }
        throw error;
    }
);

// 인증 관련 API
export const registerUser = async (data: RegisterRequest): Promise<{ message: string; user: User }> => {
    const response = await api.post('/api/register', data);
    return response.data;
};

export const loginUser = async (data: LoginRequest): Promise<LoginResponse> => {
    const response = await api.post('/api/login', data);
    return response.data;
};

export const googleLogin = async (data: GoogleLoginRequest): Promise<LoginResponse> => {
    const response = await api.post('/api/auth/google', data);
    return response.data;
};

export const getMe = async (): Promise<LoginResponse> => {
    const response = await api.get('/api/auth/me');
    return response.data;
};

// 조직 관련 API
export const getOrganizations = async (type?: OrganizationType): Promise<Organization[]> => {
    const params = type ? { type } : {};
    const response = await api.get('/api/organizations', { params });
    return response.data || []; // null 체크
};

export const createOrganization = async (data: CreateOrganizationRequest): Promise<Organization> => {
    const response = await api.post('/api/admin/organizations', data);
    return response.data;
};

export const updateOrganization = async (id: number, data: UpdateOrganizationRequest): Promise<{ message: string }> => {
    const response = await api.put(`/api/admin/organizations/${id}`, data);
    return response.data;
};

export const deleteOrganization = async (id: number): Promise<{ message: string }> => {
    const response = await api.delete(`/api/admin/organizations/${id}`);
    return response.data;
};

// 물품 관련 API
export const getItems = async (): Promise<Item[]> => {
    const response = await api.get('/api/items');
    return response.data;
};

export const getCategories = async (): Promise<Category[]> => {
    const response = await api.get('/api/categories');
    return response.data;
};

// 신청 관련 API
export const createRequest = async (data: CreateRequestData): Promise<Request> => {
    const response = await api.post('/api/requests', data);
    return response.data;
};

export const getRequests = async (): Promise<Request[]> => {
    const response = await api.get('/api/admin/requests');
    return response.data;
};

export const deleteRequest = async (id: number): Promise<{ message: string }> => {
    const response = await api.delete(`/api/admin/requests/${id}`);
    return response.data;
};

// 관리자 물품 관리 API
export const createItem = async (data: CreateItemData): Promise<Item> => {
    const response = await api.post('/api/admin/items', data);
    return response.data;
};

export const updateItem = async (id: number, data: UpdateItemData): Promise<{ message: string }> => {
    const response = await api.put(`/api/admin/items/${id}`, data);
    return response.data;
};

export const deleteItem = async (id: number): Promise<{ message: string }> => {
    const response = await api.delete(`/api/admin/items/${id}`);
    return response.data;
};

// 관리자 계정 관리 API
export const getUsers = async (): Promise<import('../types/api').UserWithAdmin[]> => {
    const response = await api.get('/api/admin/users');
    return response.data;
};

export const addAdmin = async (userId: number): Promise<{ message: string }> => {
    const response = await api.post('/api/admin/admins', { user_id: userId });
    return response.data;
};

export const removeAdmin = async (userId: number): Promise<{ message: string }> => {
    const response = await api.delete(`/api/admin/admins/${userId}`);
    return response.data;
};

// 내 신청 내역 조회
export const getMyRequests = async (): Promise<Request[]> => {
    const response = await api.get('/api/auth/requests');
    return response.data;
};

// 프로필 업데이트 (본인)
export const updateProfile = async (data: UpdateProfileData): Promise<{ message: string }> => {
    const response = await api.put('/api/auth/profile', data);
    return response.data;
};

// 관리자: 사용자 정보 수정
export const updateUserByAdmin = async (userId: number, data: UpdateUserByAdminData): Promise<{ message: string }> => {
    const response = await api.put(`/api/admin/users/${userId}`, data);
    return response.data;
};

// 관리자: 사용자 비활성화
export const deactivateUser = async (userId: number): Promise<{ message: string }> => {
    const response = await api.delete(`/api/admin/users/${userId}`);
    return response.data;
};

export default api;
