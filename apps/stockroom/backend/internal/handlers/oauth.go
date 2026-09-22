package handlers

import (
	"company-items-backend/internal/database"
	"company-items-backend/internal/models"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

// GoogleTokenPayload Google ID 토큰 검증 결과
type GoogleTokenPayload struct {
	Sub           string `json:"sub"`            // Google user ID
	Email         string `json:"email"`          // 이메일
	EmailVerified string `json:"email_verified"` // 이메일 인증 여부
	Name          string `json:"name"`           // 이름
	GivenName     string `json:"given_name"`     // 이름 (first)
	FamilyName    string `json:"family_name"`    // 성 (last)
	Picture       string `json:"picture"`        // 프로필 사진
	Aud           string `json:"aud"`            // Client ID
}

// GoogleLoginRequest 프론트에서 보내는 요청
type GoogleLoginRequest struct {
	Credential string `json:"credential" binding:"required"`
}

// GoogleLogin Google OAuth 로그인
func GoogleLogin(c *gin.Context) {
	var req GoogleLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "credential이 필요합니다"})
		return
	}

	// Google tokeninfo API로 ID 토큰 검증
	payload, err := verifyGoogleToken(req.Credential)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Google 토큰 검증 실패: " + err.Error()})
		return
	}

	// Client ID 검증
	clientID := os.Getenv("GOOGLE_CLIENT_ID")
	if clientID != "" && payload.Aud != clientID {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "잘못된 Google Client ID"})
		return
	}

	// google_id로 기존 사용자 찾기
	var user models.User
	query := `
		SELECT u.id, u.korean_name, u.english_name, u.organization_id, u.team_name,
			   u.email, u.is_active, u.created_at, u.last_login_at, o.name as organization_name
		FROM users u
		LEFT JOIN organizations o ON u.organization_id = o.id
		WHERE u.google_id = $1 AND u.is_active = true`

	err = database.DB.QueryRow(query, payload.Sub).Scan(
		&user.ID, &user.KoreanName, &user.EnglishName, &user.OrganizationID,
		&user.TeamName, &user.Email, &user.IsActive, &user.CreatedAt,
		&user.LastLoginAt, &user.OrganizationName,
	)

	if err == sql.ErrNoRows {
		// email로 기존 사용자 찾기 (google_id가 아직 연결 안 된 경우)
		emailQuery := `
			SELECT u.id, u.korean_name, u.english_name, u.organization_id, u.team_name,
				   u.email, u.is_active, u.created_at, u.last_login_at, o.name as organization_name
			FROM users u
			LEFT JOIN organizations o ON u.organization_id = o.id
			WHERE u.email = $1 AND u.is_active = true`

		err = database.DB.QueryRow(emailQuery, payload.Email).Scan(
			&user.ID, &user.KoreanName, &user.EnglishName, &user.OrganizationID,
			&user.TeamName, &user.Email, &user.IsActive, &user.CreatedAt,
			&user.LastLoginAt, &user.OrganizationName,
		)

		if err == sql.ErrNoRows {
			// 새 사용자 생성
			name := payload.Name
			if name == "" {
				name = strings.Split(payload.Email, "@")[0]
			}

			insertQuery := `
				INSERT INTO users (korean_name, english_name, password_hash, team_name, email, google_id)
				VALUES ($1, $2, '', $3, $4, $5)
				RETURNING id, korean_name, english_name, organization_id, team_name, email, is_active, created_at`

			err = database.DB.QueryRow(
				insertQuery, name, name, "", payload.Email, payload.Sub,
			).Scan(
				&user.ID, &user.KoreanName, &user.EnglishName, &user.OrganizationID,
				&user.TeamName, &user.Email, &user.IsActive, &user.CreatedAt,
			)

			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "사용자 생성 실패: " + err.Error()})
				return
			}
		} else if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
			return
		} else {
			// 기존 사용자에 google_id 연결
			database.DB.Exec("UPDATE users SET google_id = $1 WHERE id = $2", payload.Sub, user.ID)
		}
	} else if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "데이터베이스 오류"})
		return
	}

	// 로그인 시간 업데이트
	database.DB.Exec("UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = $1", user.ID)

	// JWT 토큰 생성
	token, err := generateJWT(user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "토큰 생성 실패"})
		return
	}

	c.JSON(http.StatusOK, models.LoginResponse{
		User:    user,
		Token:   token,
		IsAdmin: isAdmin(user.ID),
	})
}

// verifyGoogleToken Google tokeninfo API로 토큰 검증
func verifyGoogleToken(idToken string) (*GoogleTokenPayload, error) {
	resp, err := http.Get("https://oauth2.googleapis.com/tokeninfo?id_token=" + idToken)
	if err != nil {
		return nil, fmt.Errorf("Google API 호출 실패: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("응답 읽기 실패: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("토큰 검증 실패 (status %d)", resp.StatusCode)
	}

	var payload GoogleTokenPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, fmt.Errorf("응답 파싱 실패: %v", err)
	}

	if payload.Email == "" {
		return nil, fmt.Errorf("이메일 정보를 가져올 수 없습니다")
	}

	return &payload, nil
}
