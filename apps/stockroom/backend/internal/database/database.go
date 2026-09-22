package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"
)

var DB *sql.DB

// InitDB 데이터베이스 초기화
func InitDB() error {
	host := getEnv("DB_HOST", "localhost")
	port := getEnv("DB_PORT", "5432")
	user := getEnv("DB_USER", "admin")
	password := getEnv("DB_PASSWORD", "password123")
	dbname := getEnv("DB_NAME", "company_items")

	psqlInfo := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname)

	var err error
	DB, err = sql.Open("postgres", psqlInfo)
	if err != nil {
		return fmt.Errorf("데이터베이스 연결 실패: %v", err)
	}

	err = DB.Ping()
	if err != nil {
		return fmt.Errorf("데이터베이스 ping 실패: %v", err)
	}

	log.Println("데이터베이스 연결 성공")
	return nil
}

// CloseDB 데이터베이스 연결 종료
func CloseDB() {
	if DB != nil {
		DB.Close()
	}
}

// getEnv 환경변수 가져오기 (기본값 지원)
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
