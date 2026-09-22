package main

import (
	"company-items-backend/internal/database"
	"company-items-backend/internal/handlers"
	"company-items-backend/internal/middleware"
	"log"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// 환경변수 로드
	if err := godotenv.Load(); err != nil {
		log.Println("Warning: .env file not found")
	}

	// 데이터베이스 초기화
	if err := database.InitDB(); err != nil {
		log.Fatal("데이터베이스 초기화 실패:", err)
	}
	defer database.CloseDB()

	// Gin 라우터 설정
	r := gin.Default()

	// CORS 설정
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true // 모든 Origin 허용 (개발환경)
	config.AllowMethods = []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Content-Length", "Accept-Encoding", "X-CSRF-Token", "Authorization"}
	config.AllowCredentials = true
	r.Use(cors.New(config))

	// API 라우트 설정
	api := r.Group("/api")
	{
		// 인증 관련 엔드포인트
		api.POST("/register", handlers.RegisterUser)
		api.POST("/login", handlers.LoginUser)
		api.POST("/auth/google", handlers.GoogleLogin)

		// 인증 필요 엔드포인트
		auth := api.Group("/auth")
		auth.Use(middleware.AuthMiddleware())
		{
			auth.GET("/me", handlers.GetMe)
			auth.PUT("/profile", handlers.UpdateProfile)
			auth.GET("/requests", handlers.GetMyRequests)
		}

		// 조직 관련 엔드포인트
		api.GET("/organizations", handlers.GetOrganizations)

		// 공개 엔드포인트
		api.GET("/items", handlers.GetItems)
		api.GET("/categories", handlers.GetCategories)
		api.POST("/requests", handlers.CreateRequest)

		// 관리자 엔드포인트 (인증 + 어드민 권한 필요)
		admin := api.Group("/admin")
		admin.Use(middleware.AuthMiddleware(), middleware.AdminMiddleware())
		{
			admin.POST("/organizations", handlers.CreateOrganization)
			admin.PUT("/organizations/:id", handlers.UpdateOrganization)
			admin.DELETE("/organizations/:id", handlers.DeleteOrganization)
			admin.GET("/requests", handlers.GetRequests)
			admin.DELETE("/requests/:id", handlers.DeleteRequest)
			admin.POST("/items", handlers.CreateItem)
			admin.PUT("/items/:id", handlers.UpdateItem)
			admin.DELETE("/items/:id", handlers.DeleteItem)
			admin.GET("/users", handlers.GetUsers)
			admin.PUT("/users/:id", handlers.UpdateUserByAdmin)
			admin.DELETE("/users/:id", handlers.DeactivateUser)
			admin.POST("/admins", handlers.AddAdmin)
			admin.DELETE("/admins/:user_id", handlers.RemoveAdmin)
		}
	}

	// 헬스체크 엔드포인트
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "ok",
			"message": "창고지기 API Server is running",
		})
	})

	// 서버 시작
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("서버가 포트 %s에서 실행됩니다", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal("서버 시작 실패:", err)
	}
}
