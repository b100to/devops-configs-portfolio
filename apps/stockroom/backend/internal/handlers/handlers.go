package handlers

import (
	"company-items-backend/internal/database"
	"company-items-backend/internal/middleware"
	"company-items-backend/internal/models"
	"database/sql"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// generateJWT JWT 토큰 생성
func generateJWT(userID int) (string, error) {
	claims := jwt.MapClaims{
		"user_id": userID,
		"exp":     time.Now().Add(30 * 24 * time.Hour).Unix(),
		"iat":     time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(middleware.GetJWTSecret())
}

// isAdmin admins 테이블에서 어드민 여부 확인
func isAdmin(userID int) bool {
	var count int
	err := database.DB.QueryRow("SELECT COUNT(*) FROM admins WHERE user_id = $1", userID).Scan(&count)
	return err == nil && count > 0
}

// RegisterUser - 회원가입
func RegisterUser(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 패스워드 해시화
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "패스워드 처리 오류"})
		return
	}

	// 이름 중복 확인 (korean_name 또는 english_name에 같은 이름이 있는지)
	var existingID int
	checkQuery := `SELECT id FROM users WHERE korean_name = $1 OR english_name = $1 LIMIT 1`
	err = database.DB.QueryRow(checkQuery, req.Name).Scan(&existingID)
	if err != sql.ErrNoRows {
		c.JSON(http.StatusConflict, gin.H{"error": "이미 존재하는 사용자명입니다"})
		return
	}

	// 사용자 생성 (name을 korean_name, english_name 둘 다에 저장)
	insertQuery := `
		INSERT INTO users (korean_name, english_name, password_hash, organization_id, team_name, email)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, korean_name, english_name, organization_id, team_name, email, is_active, created_at`

	var user models.User
	err = database.DB.QueryRow(
		insertQuery,
		req.Name,
		req.Name,
		string(hashedPassword),
		req.OrganizationID,
		req.TeamName,
		req.Email,
	).Scan(
		&user.ID,
		&user.KoreanName,
		&user.EnglishName,
		&user.OrganizationID,
		&user.TeamName,
		&user.Email,
		&user.IsActive,
		&user.CreatedAt,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "사용자 생성 실패"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "회원가입이 완료되었습니다",
		"user":    user,
	})
}

// LoginUser - 로그인
func LoginUser(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 사용자 조회 (한글 또는 영어 이름)
	query := `
		SELECT u.id, u.korean_name, u.english_name, u.password_hash, u.organization_id, u.team_name, 
			   u.email, u.is_active, u.created_at, u.last_login_at, o.name as organization_name
		FROM users u
		LEFT JOIN organizations o ON u.organization_id = o.id
		WHERE (u.korean_name = $1 OR u.english_name = $1) AND u.is_active = true
		LIMIT 1`

	var user models.User
	var passwordHash string
	err := database.DB.QueryRow(query, req.Name).Scan(
		&user.ID,
		&user.KoreanName,
		&user.EnglishName,
		&passwordHash,
		&user.OrganizationID,
		&user.TeamName,
		&user.Email,
		&user.IsActive,
		&user.CreatedAt,
		&user.LastLoginAt,
		&user.OrganizationName,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "사용자를 찾을 수 없습니다"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
		return
	}

	// 패스워드 확인
	err = bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "패스워드가 올바르지 않습니다"})
		return
	}

	// 로그인 시간 업데이트
	updateQuery := `UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = $1`
	database.DB.Exec(updateQuery, user.ID)

	// JWT 토큰 생성
	token, err := generateJWT(user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "토큰 생성 실패"})
		return
	}

	response := models.LoginResponse{
		User:    user,
		Token:   token,
		IsAdmin: isAdmin(user.ID),
	}

	c.JSON(http.StatusOK, response)
}

// GetMe - 현재 로그인 사용자 정보 (JWT 토큰으로 조회)
func GetMe(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "인증이 필요합니다"})
		return
	}

	query := `
		SELECT u.id, u.korean_name, u.english_name, u.organization_id, u.team_name,
			   u.email, u.is_active, u.created_at, u.last_login_at, o.name as organization_name
		FROM users u
		LEFT JOIN organizations o ON u.organization_id = o.id
		WHERE u.id = $1 AND u.is_active = true`

	var user models.User
	err := database.DB.QueryRow(query, userID).Scan(
		&user.ID,
		&user.KoreanName,
		&user.EnglishName,
		&user.OrganizationID,
		&user.TeamName,
		&user.Email,
		&user.IsActive,
		&user.CreatedAt,
		&user.LastLoginAt,
		&user.OrganizationName,
	)

	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "사용자를 찾을 수 없습니다"})
		return
	}

	c.JSON(http.StatusOK, models.LoginResponse{
		User:    user,
		IsAdmin: isAdmin(user.ID),
	})
}

// UpdateProfile - 프로필 업데이트 (본인만)
func UpdateProfile(c *gin.Context) {
	userID, _ := c.Get("user_id")

	var req struct {
		KoreanName     *string `json:"korean_name"`
		EnglishName    *string `json:"english_name"`
		TeamName       *string `json:"team_name"`
		OrganizationID *int    `json:"organization_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	setParts := []string{}
	args := []interface{}{}
	argIndex := 1

	if req.KoreanName != nil {
		setParts = append(setParts, "korean_name = $"+strconv.Itoa(argIndex))
		args = append(args, *req.KoreanName)
		argIndex++
	}
	if req.EnglishName != nil {
		setParts = append(setParts, "english_name = $"+strconv.Itoa(argIndex))
		args = append(args, *req.EnglishName)
		argIndex++
	}
	if req.TeamName != nil {
		setParts = append(setParts, "team_name = $"+strconv.Itoa(argIndex))
		args = append(args, *req.TeamName)
		argIndex++
	}
	if req.OrganizationID != nil {
		setParts = append(setParts, "organization_id = $"+strconv.Itoa(argIndex))
		args = append(args, *req.OrganizationID)
		argIndex++
	}

	if len(setParts) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "수정할 데이터가 없습니다"})
		return
	}

	query := "UPDATE users SET " + strings.Join(setParts, ", ") + " WHERE id = $" + strconv.Itoa(argIndex)
	args = append(args, userID)

	_, err := database.DB.Exec(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "프로필 업데이트 실패"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "프로필이 업데이트되었습니다"})
}

// UpdateUserByAdmin - 관리자가 사용자 정보 수정
func UpdateUserByAdmin(c *gin.Context) {
	targetID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "잘못된 ID 형식"})
		return
	}

	var req struct {
		KoreanName     *string `json:"korean_name"`
		EnglishName    *string `json:"english_name"`
		TeamName       *string `json:"team_name"`
		OrganizationID *int    `json:"organization_id"`
		IsActive       *bool   `json:"is_active"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	setParts := []string{}
	args := []interface{}{}
	argIndex := 1

	if req.KoreanName != nil {
		setParts = append(setParts, "korean_name = $"+strconv.Itoa(argIndex))
		args = append(args, *req.KoreanName)
		argIndex++
	}
	if req.EnglishName != nil {
		setParts = append(setParts, "english_name = $"+strconv.Itoa(argIndex))
		args = append(args, *req.EnglishName)
		argIndex++
	}
	if req.TeamName != nil {
		setParts = append(setParts, "team_name = $"+strconv.Itoa(argIndex))
		args = append(args, *req.TeamName)
		argIndex++
	}
	if req.OrganizationID != nil {
		setParts = append(setParts, "organization_id = $"+strconv.Itoa(argIndex))
		args = append(args, *req.OrganizationID)
		argIndex++
	}
	if req.IsActive != nil {
		setParts = append(setParts, "is_active = $"+strconv.Itoa(argIndex))
		args = append(args, *req.IsActive)
		argIndex++
	}

	if len(setParts) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "수정할 데이터가 없습니다"})
		return
	}

	query := "UPDATE users SET " + strings.Join(setParts, ", ") + " WHERE id = $" + strconv.Itoa(argIndex)
	args = append(args, targetID)

	_, err = database.DB.Exec(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "사용자 수정 실패"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "사용자 정보가 수정되었습니다"})
}

// DeactivateUser - 관리자가 사용자 비활성화
func DeactivateUser(c *gin.Context) {
	targetID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "잘못된 ID 형식"})
		return
	}

	// 본인 비활성화 방지
	currentUserID, _ := c.Get("user_id")
	if currentUserID.(int) == targetID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "본인 계정은 비활성화할 수 없습니다"})
		return
	}

	result, err := database.DB.Exec("UPDATE users SET is_active = false WHERE id = $1", targetID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "사용자 비활성화 실패"})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "사용자를 찾을 수 없습니다"})
		return
	}

	// 어드민 권한도 제거
	database.DB.Exec("DELETE FROM admins WHERE user_id = $1", targetID)

	c.JSON(http.StatusOK, gin.H{"message": "사용자가 비활성화되었습니다"})
}

// GetOrganizations - 조직 목록 조회
// Query params: type (optional) - company, organization, team
func GetOrganizations(c *gin.Context) {
	orgType := c.Query("type")

	query := `SELECT id, name, type, description, is_active, created_at FROM organizations WHERE is_active = true`
	args := []interface{}{}

	if orgType != "" {
		query += ` AND type = $1`
		args = append(args, orgType)
	}
	query += ` ORDER BY type, name`

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
		return
	}
	defer rows.Close()

	organizations := []models.Organization{} // nil 대신 빈 슬라이스로 초기화
	for rows.Next() {
		var org models.Organization
		err := rows.Scan(&org.ID, &org.Name, &org.Type, &org.Description, &org.IsActive, &org.CreatedAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터 처리 오류"})
			return
		}
		organizations = append(organizations, org)
	}

	c.JSON(http.StatusOK, organizations)
}

// CreateOrganization - 조직 생성 (관리자 전용)
func CreateOrganization(c *gin.Context) {
	var req models.CreateOrganizationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 중복 확인
	var existingID int
	checkQuery := `SELECT id FROM organizations WHERE name = $1 LIMIT 1`
	err := database.DB.QueryRow(checkQuery, req.Name).Scan(&existingID)
	if err != sql.ErrNoRows {
		c.JSON(http.StatusConflict, gin.H{"error": "이미 존재하는 이름입니다"})
		return
	}

	// 조직 생성
	insertQuery := `
		INSERT INTO organizations (name, type, description)
		VALUES ($1, $2, $3)
		RETURNING id, name, type, description, is_active, created_at`

	var org models.Organization
	err = database.DB.QueryRow(insertQuery, req.Name, req.Type, req.Description).Scan(
		&org.ID, &org.Name, &org.Type, &org.Description, &org.IsActive, &org.CreatedAt,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "조직 생성 실패"})
		return
	}

	c.JSON(http.StatusCreated, org)
}

// GetItems 물품 목록 조회 (주문 많은 순 정렬)
func GetItems(c *gin.Context) {
	query := `
		SELECT i.id, i.name, i.description, i.category_id, c.name as category_name,
			   i.available_quantity, i.max_per_user, i.image_url, i.is_active,
			   i.created_at, i.updated_at,
			   COALESCE(req.total_qty, 0) as order_count
		FROM items i
		LEFT JOIN categories c ON i.category_id = c.id
		LEFT JOIN (
			SELECT item_id, SUM(quantity) as total_qty
			FROM requests
			GROUP BY item_id
		) req ON i.id = req.item_id
		WHERE i.is_active = true
		ORDER BY order_count DESC, i.name`

	rows, err := database.DB.Query(query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
		return
	}
	defer rows.Close()

	var items []models.Item
	for rows.Next() {
		var item models.Item
		err := rows.Scan(
			&item.ID, &item.Name, &item.Description, &item.CategoryID, &item.CategoryName,
			&item.AvailableQuantity, &item.MaxPerUser, &item.ImageURL, &item.IsActive,
			&item.CreatedAt, &item.UpdatedAt, &item.OrderCount)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터 처리 오류"})
			return
		}
		items = append(items, item)
	}

	c.JSON(http.StatusOK, items)
}

// GetCategories 카테고리 목록 조회
func GetCategories(c *gin.Context) {
	query := `SELECT id, name, description, created_at FROM categories ORDER BY name`

	rows, err := database.DB.Query(query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
		return
	}
	defer rows.Close()

	var categories []models.Category
	for rows.Next() {
		var category models.Category
		err := rows.Scan(&category.ID, &category.Name, &category.Description, &category.CreatedAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터 처리 오류"})
			return
		}
		categories = append(categories, category)
	}

	c.JSON(http.StatusOK, categories)
}

// CreateRequest 물품 신청
func CreateRequest(c *gin.Context) {
	var req models.CreateRequestRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 물품 존재 확인
	var exists bool
	err := database.DB.QueryRow(`SELECT EXISTS(SELECT 1 FROM items WHERE id = $1 AND is_active = true)`, req.ItemID).Scan(&exists)
	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "물품을 찾을 수 없습니다"})
		return
	}

	// 신청 생성 (즉시 완료 상태로)
	insertQuery := `
		INSERT INTO requests (user_id, item_id, quantity, status, notes, processed_at, processed_by)
		VALUES ($1, $2, $3, 'completed', $4, CURRENT_TIMESTAMP, $1)
		RETURNING id, user_id, item_id, quantity, status, notes, requested_at, processed_at, processed_by`

	var request models.Request
	err = database.DB.QueryRow(insertQuery, req.UserID, req.ItemID, req.Quantity, req.Notes).Scan(
		&request.ID, &request.UserID, &request.ItemID, &request.Quantity,
		&request.Status, &request.Notes, &request.RequestedAt, &request.ProcessedAt, &request.ProcessedBy,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "신청 생성 실패"})
		return
	}

	c.JSON(http.StatusCreated, request)
}

// GetRequests 신청 목록 조회 (관리자 전용)
func GetRequests(c *gin.Context) {
	query := `
		SELECT r.id, r.user_id, r.item_id, r.quantity, r.status, r.notes,
			   r.requested_at, r.processed_at, r.processed_by,
			   u.korean_name as user_name, u.english_name as user_english_name,
			   i.name as item_name,
			   p.korean_name as processor_name
		FROM requests r
		LEFT JOIN users u ON r.user_id = u.id
		LEFT JOIN items i ON r.item_id = i.id
		LEFT JOIN users p ON r.processed_by = p.id
		ORDER BY r.requested_at DESC`

	rows, err := database.DB.Query(query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
		return
	}
	defer rows.Close()

	var requests []models.Request
	for rows.Next() {
		var request models.Request
		err := rows.Scan(
			&request.ID, &request.UserID, &request.ItemID, &request.Quantity,
			&request.Status, &request.Notes, &request.RequestedAt,
			&request.ProcessedAt, &request.ProcessedBy,
			&request.UserName, &request.UserEnglishName, &request.ItemName, &request.ProcessorName,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터 처리 오류"})
			return
		}
		requests = append(requests, request)
	}

	c.JSON(http.StatusOK, requests)
}

// GetMyRequests 내 신청 내역 조회
func GetMyRequests(c *gin.Context) {
	userID, _ := c.Get("user_id")

	query := `
		SELECT r.id, r.user_id, r.item_id, r.quantity, r.status, r.notes,
			   r.requested_at, r.processed_at, r.processed_by,
			   i.name as item_name
		FROM requests r
		LEFT JOIN items i ON r.item_id = i.id
		WHERE r.user_id = $1
		ORDER BY r.requested_at DESC
		LIMIT 50`

	rows, err := database.DB.Query(query, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
		return
	}
	defer rows.Close()

	var requests []models.Request
	for rows.Next() {
		var request models.Request
		err := rows.Scan(
			&request.ID, &request.UserID, &request.ItemID, &request.Quantity,
			&request.Status, &request.Notes, &request.RequestedAt,
			&request.ProcessedAt, &request.ProcessedBy,
			&request.ItemName,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터 처리 오류"})
			return
		}
		requests = append(requests, request)
	}

	c.JSON(http.StatusOK, requests)
}

// CreateItem 물품 생성 (관리자 전용)
func CreateItem(c *gin.Context) {
	var req models.CreateItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	insertQuery := `
		INSERT INTO items (name, description, category_id, available_quantity, max_per_user, image_url)
		VALUES ($1, $2, $3, 9999, 10, $4)
		RETURNING id, name, description, category_id, available_quantity, max_per_user,
				  image_url, is_active, created_at, updated_at`

	var item models.Item
	err := database.DB.QueryRow(
		insertQuery,
		req.Name, req.Description, req.CategoryID, req.ImageURL,
	).Scan(
		&item.ID, &item.Name, &item.Description, &item.CategoryID,
		&item.AvailableQuantity, &item.MaxPerUser, &item.ImageURL,
		&item.IsActive, &item.CreatedAt, &item.UpdatedAt,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "물품 생성 실패"})
		return
	}

	c.JSON(http.StatusCreated, item)
}

// UpdateItem 물품 수정 (관리자 전용)
func UpdateItem(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "잘못된 ID 형식"})
		return
	}

	var req models.UpdateItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// 동적 쿼리 빌드
	setParts := []string{}
	args := []interface{}{}
	argIndex := 1

	if req.Name != nil {
		setParts = append(setParts, "name = $"+strconv.Itoa(argIndex))
		args = append(args, *req.Name)
		argIndex++
	}
	if req.Description != nil {
		setParts = append(setParts, "description = $"+strconv.Itoa(argIndex))
		args = append(args, *req.Description)
		argIndex++
	}
	if req.CategoryID != nil {
		setParts = append(setParts, "category_id = $"+strconv.Itoa(argIndex))
		args = append(args, *req.CategoryID)
		argIndex++
	}
	if req.ImageURL != nil {
		setParts = append(setParts, "image_url = $"+strconv.Itoa(argIndex))
		args = append(args, *req.ImageURL)
		argIndex++
	}
	if req.IsActive != nil {
		setParts = append(setParts, "is_active = $"+strconv.Itoa(argIndex))
		args = append(args, *req.IsActive)
		argIndex++
	}

	if len(setParts) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "수정할 데이터가 없습니다"})
		return
	}

	query := "UPDATE items SET " + strings.Join(setParts, ", ") + " WHERE id = $" + strconv.Itoa(argIndex)
	args = append(args, id)

	_, err = database.DB.Exec(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "물품 수정 실패"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "물품이 수정되었습니다"})
}

// DeleteItem 물품 삭제 (관리자 전용)
func DeleteItem(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "잘못된 ID 형식"})
		return
	}

	query := `UPDATE items SET is_active = false WHERE id = $1`
	result, err := database.DB.Exec(query, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "물품을 찾을 수 없습니다"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "물품이 삭제되었습니다"})
}

// GetUsers 사용자 목록 조회 (관리자 전용)
func GetUsers(c *gin.Context) {
	query := `
		SELECT u.id, u.korean_name, u.english_name, u.email, u.team_name,
			   o.name as organization_name, u.is_active,
			   CASE WHEN a.id IS NOT NULL THEN true ELSE false END as is_admin
		FROM users u
		LEFT JOIN organizations o ON u.organization_id = o.id
		LEFT JOIN admins a ON u.id = a.user_id
		WHERE u.is_active = true
		ORDER BY u.korean_name`

	rows, err := database.DB.Query(query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
		return
	}
	defer rows.Close()

	type UserWithAdmin struct {
		ID               int     `json:"id"`
		KoreanName       string  `json:"korean_name"`
		EnglishName      string  `json:"english_name"`
		Email            *string `json:"email"`
		TeamName         string  `json:"team_name"`
		OrganizationName *string `json:"organization_name"`
		IsActive         bool    `json:"is_active"`
		IsAdmin          bool    `json:"is_admin"`
	}

	var users []UserWithAdmin
	for rows.Next() {
		var u UserWithAdmin
		err := rows.Scan(&u.ID, &u.KoreanName, &u.EnglishName, &u.Email, &u.TeamName,
			&u.OrganizationName, &u.IsActive, &u.IsAdmin)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터 처리 오류"})
			return
		}
		users = append(users, u)
	}

	c.JSON(http.StatusOK, users)
}

// AddAdmin 어드민 추가 (관리자 전용)
func AddAdmin(c *gin.Context) {
	var req struct {
		UserID int `json:"user_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_id가 필요합니다"})
		return
	}

	// 사용자 존재 확인
	var exists bool
	database.DB.QueryRow("SELECT EXISTS(SELECT 1 FROM users WHERE id = $1 AND is_active = true)", req.UserID).Scan(&exists)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "사용자를 찾을 수 없습니다"})
		return
	}

	// 이미 어드민인지 확인
	var adminExists bool
	database.DB.QueryRow("SELECT EXISTS(SELECT 1 FROM admins WHERE user_id = $1)", req.UserID).Scan(&adminExists)
	if adminExists {
		c.JSON(http.StatusConflict, gin.H{"error": "이미 관리자입니다"})
		return
	}

	_, err := database.DB.Exec("INSERT INTO admins (user_id, role) VALUES ($1, 'admin')", req.UserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "관리자 추가 실패"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "관리자가 추가되었습니다"})
}

// RemoveAdmin 어드민 제거 (관리자 전용)
func RemoveAdmin(c *gin.Context) {
	userIDStr := c.Param("user_id")
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "잘못된 ID 형식"})
		return
	}

	// 본인 제거 방지
	currentUserID, _ := c.Get("user_id")
	if currentUserID.(int) == userID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "본인의 관리자 권한은 제거할 수 없습니다"})
		return
	}

	result, err := database.DB.Exec("DELETE FROM admins WHERE user_id = $1", userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "관리자 제거 실패"})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "관리자를 찾을 수 없습니다"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "관리자가 제거되었습니다"})
}

// DeleteRequest 신청 내역 삭제 (관리자 전용, hard delete)
func DeleteRequest(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "잘못된 ID 형식"})
		return
	}

	result, err := database.DB.Exec("DELETE FROM requests WHERE id = $1", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "신청 삭제 실패"})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "신청을 찾을 수 없습니다"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "신청이 삭제되었습니다"})
}

// UpdateOrganization 조직 수정 (관리자 전용)
func UpdateOrganization(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "잘못된 ID 형식"})
		return
	}

	var req models.UpdateOrganizationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	setParts := []string{}
	args := []interface{}{}
	argIndex := 1

	if req.Name != nil {
		setParts = append(setParts, "name = $"+strconv.Itoa(argIndex))
		args = append(args, *req.Name)
		argIndex++
	}
	if req.Type != nil {
		setParts = append(setParts, "type = $"+strconv.Itoa(argIndex))
		args = append(args, *req.Type)
		argIndex++
	}
	if req.Description != nil {
		setParts = append(setParts, "description = $"+strconv.Itoa(argIndex))
		args = append(args, *req.Description)
		argIndex++
	}

	if len(setParts) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "수정할 데이터가 없습니다"})
		return
	}

	query := "UPDATE organizations SET " + strings.Join(setParts, ", ") + " WHERE id = $" + strconv.Itoa(argIndex)
	args = append(args, id)

	result, err := database.DB.Exec(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "조직 수정 실패"})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "조직을 찾을 수 없습니다"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "조직이 수정되었습니다"})
}

// DeleteOrganization 조직 삭제 (관리자 전용, soft delete)
func DeleteOrganization(c *gin.Context) {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "잘못된 ID 형식"})
		return
	}

	result, err := database.DB.Exec("UPDATE organizations SET is_active = false WHERE id = $1", id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "조직 삭제 실패"})
		return
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "조직을 찾을 수 없습니다"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "조직이 삭제되었습니다"})
}
