package models

import "time"

// Organization 구조체 (회사/조직/팀 통합)
// Type: "company" (회사), "organization" (조직/실), "team" (팀)
type Organization struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Type        string    `json:"type" db:"type"`
	Description *string   `json:"description" db:"description"`
	IsActive    bool      `json:"is_active" db:"is_active"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// User 구조체
type User struct {
	ID             int        `json:"id" db:"id"`
	KoreanName     string     `json:"korean_name" db:"korean_name"`
	EnglishName    string     `json:"english_name" db:"english_name"`
	PasswordHash   string     `json:"-" db:"password_hash"` // JSON에서 제외
	OrganizationID *int       `json:"organization_id" db:"organization_id"`
	TeamName       string     `json:"team_name" db:"team_name"`
	Email          *string    `json:"email" db:"email"`
	IsActive       bool       `json:"is_active" db:"is_active"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	LastLoginAt    *time.Time `json:"last_login_at" db:"last_login_at"`
	// 관계 필드
	OrganizationName *string `json:"organization_name,omitempty"`
}

// Category 구조체
type Category struct {
	ID          int       `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description *string   `json:"description" db:"description"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// Item 구조체
type Item struct {
	ID                int       `json:"id" db:"id"`
	Name              string    `json:"name" db:"name"`
	Description       *string   `json:"description" db:"description"`
	CategoryID        *int      `json:"category_id" db:"category_id"`
	CategoryName      *string   `json:"category_name,omitempty"`
	AvailableQuantity int       `json:"available_quantity" db:"available_quantity"`
	MaxPerUser        int       `json:"max_per_user" db:"max_per_user"`
	ImageURL          *string   `json:"image_url" db:"image_url"`
	IsActive          bool      `json:"is_active" db:"is_active"`
	CreatedAt         time.Time `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time `json:"updated_at" db:"updated_at"`
	OrderCount        int       `json:"order_count"`
}

// Request 구조체
type Request struct {
	ID          int        `json:"id" db:"id"`
	UserID      int        `json:"user_id" db:"user_id"`
	ItemID      int        `json:"item_id" db:"item_id"`
	Quantity    int        `json:"quantity" db:"quantity"`
	Status      string     `json:"status" db:"status"`
	Notes       *string    `json:"notes" db:"notes"`
	RequestedAt time.Time  `json:"requested_at" db:"requested_at"`
	ProcessedAt *time.Time `json:"processed_at" db:"processed_at"`
	ProcessedBy *int       `json:"processed_by" db:"processed_by"`
	// 관계 필드
	UserName        *string `json:"user_name,omitempty"`
	UserEnglishName *string `json:"user_english_name,omitempty"`
	ItemName        *string `json:"item_name,omitempty"`
	ProcessorName   *string `json:"processor_name,omitempty"`
}

// Admin 구조체
type Admin struct {
	ID        int       `json:"id" db:"id"`
	UserID    int       `json:"user_id" db:"user_id"`
	Role      string    `json:"role" db:"role"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

// DTO 구조체들

// RegisterRequest - 회원가입 요청
type RegisterRequest struct {
	Name           string `json:"name" binding:"required"`              // 이름 (한글/영어 통용)
	Password       string `json:"password" binding:"required,len=4"`    // 정확히 4자리
	OrganizationID *int   `json:"organization_id"`
	TeamName       string `json:"team_name" binding:"required"`
	Email          string `json:"email" binding:"omitempty,email"`
}

// LoginRequest - 로그인 요청
type LoginRequest struct {
	Name     string `json:"name" binding:"required"` // 한글 또는 영어 이름
	Password string `json:"password" binding:"required,len=4"`
}

// LoginResponse - 로그인 응답
type LoginResponse struct {
	User    User   `json:"user"`
	Token   string `json:"token"`
	IsAdmin bool   `json:"is_admin"`
}

// CreateOrganizationRequest - 조직 생성 요청
type CreateOrganizationRequest struct {
	Name        string  `json:"name" binding:"required"`
	Type        string  `json:"type" binding:"required,oneof=company organization team"`
	Description *string `json:"description"`
}

// UpdateOrganizationRequest - 조직 수정 요청
type UpdateOrganizationRequest struct {
	Name        *string `json:"name"`
	Type        *string `json:"type" binding:"omitempty,oneof=company organization team"`
	Description *string `json:"description"`
}

// CreateItemRequest DTO
type CreateItemRequest struct {
	Name        string  `json:"name" binding:"required"`
	Description *string `json:"description"`
	CategoryID  *int    `json:"category_id"`
	ImageURL    *string `json:"image_url"`
}

// UpdateItemRequest DTO
type UpdateItemRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	CategoryID  *int    `json:"category_id"`
	ImageURL    *string `json:"image_url"`
	IsActive    *bool   `json:"is_active"`
}

// CreateRequestRequest DTO
type CreateRequestRequest struct {
	UserID   int     `json:"user_id" binding:"required"`
	ItemID   int     `json:"item_id" binding:"required"`
	Quantity int     `json:"quantity" binding:"min=1"`
	Notes    *string `json:"notes"`
}
