// API 관련 타입 정의 (v2)

export type OrganizationType = 'company' | 'organization' | 'team';

export interface Organization {
    id: number;
    name: string;
    type: OrganizationType;
    description?: string;
    is_active: boolean;
    created_at: string;
}

export interface User {
    id: number;
    korean_name?: string;
    english_name: string;
    organization_id?: number;
    team_name: string;
    email?: string;
    is_active: boolean;
    created_at: string;
    last_login_at?: string;
    organization_name?: string;
}

export interface Category {
    id: number;
    name: string;
    description?: string;
    created_at: string;
}

export interface Item {
    id: number;
    name: string;
    description?: string;
    category_id?: number;
    category_name?: string;
    available_quantity: number;
    max_per_user: number;
    image_url?: string;
    is_active: boolean;
    created_at: string;
    updated_at: string;
    order_count: number;
}

export interface Request {
    id: number;
    user_id: number;
    item_id: number;
    quantity: number;
    status: 'pending' | 'approved' | 'rejected' | 'delivered';
    notes?: string;
    requested_at: string;
    processed_at?: string;
    processed_by?: number;
    user_name?: string;
    user_english_name?: string;
    item_name?: string;
    processor_name?: string;
}

// Request DTOs
export interface RegisterRequest {
    name: string;
    password: string; // 4자리
    organization_id?: number;
    team_name: string;
    email?: string;
}

export interface LoginRequest {
    name: string; // 한글 또는 영어 이름
    password: string; // 4자리
}

export interface LoginResponse {
    user: User;
    token: string;
    is_admin: boolean;
}

export interface GoogleLoginRequest {
    credential: string;
}

export interface CreateOrganizationRequest {
    name: string;
    type: OrganizationType;
    description?: string;
}

export interface UpdateOrganizationRequest {
    name?: string;
    type?: OrganizationType;
    description?: string;
}

export interface CreateRequestData {
    user_id: number;
    item_id: number;
    quantity: number;
    notes?: string;
}

export interface CreateItemData {
    name: string;
    description?: string;
    category_id?: number;
    image_url?: string;
}

export interface UpdateItemData {
    name?: string;
    description?: string;
    category_id?: number;
    image_url?: string;
    is_active?: boolean;
}

export interface UserWithAdmin {
    id: number;
    korean_name?: string;
    english_name: string;
    email?: string;
    team_name: string;
    organization_name?: string;
    is_active: boolean;
    is_admin: boolean;
}

export interface UpdateProfileData {
    english_name?: string;
    team_name?: string;
    organization_id?: number;
}

export interface UpdateUserByAdminData {
    english_name?: string;
    team_name?: string;
    organization_id?: number;
    is_active?: boolean;
}