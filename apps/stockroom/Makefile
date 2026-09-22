# company-supply Makefile
# ─────────────────────────────────────────────────
# 배포는 GitHub Actions (.github/workflows/company-supply.yml)
# ─────────────────────────────────────────────────

# ─── Local ────────────────────────────────────────

.PHONY: dev dev-backend dev-frontend dev-db dev-stop test-api up down down-v logs
.PHONY: dev-local dev-backend-local dev-frontend-local dev-db-local dev-stop-local dev-restart-backend shell-db-local

DB_PORT      ?= 5432
BACKEND_PORT ?= 8080

## 로컬 개발 전체 실행 (DB docker + backend/frontend 로컬)
dev: dev-db
	@sleep 3
	$(MAKE) dev-backend &
	$(MAKE) dev-frontend &
	@echo ""
	@echo "Frontend: http://localhost:3000"
	@echo "Backend:  http://localhost:8080"
	@echo "DB:       localhost:5433"
	@wait

## 백엔드 로컬 실행
dev-backend:
	cd backend && DB_HOST=localhost DB_PORT=5433 DB_USER=admin DB_PASSWORD=password123 DB_NAME=company_items go run cmd/main.go

## 프론트엔드 로컬 실행
dev-frontend:
	cd frontend && npm install --silent && VITE_API_URL=http://localhost:8080 npm start

## DB만 실행 (docker)
dev-db:
	docker compose up -d postgres
	@echo "Waiting for DB..."
	@until docker exec company_items_db pg_isready -U admin -d company_items > /dev/null 2>&1; do sleep 1; done
	@echo "DB ready on localhost:5433"

## 로컬 개발 중지
dev-stop:
	-@pkill -f "go run cmd/main.go" 2>/dev/null
	-@pkill -f "vite" 2>/dev/null
	docker compose down
	@echo "Stopped."

# ─── Local (Docker 없이) ────────────────────────

## 로컬 개발 전체 실행 (Docker 없이, brew PostgreSQL 사용)
dev-local: dev-stop-local dev-db-local
	@sleep 1
	$(MAKE) dev-backend-local &
	$(MAKE) dev-frontend-local &
	@echo ""
	@echo "Frontend: http://localhost:3000"
	@echo "Backend:  http://localhost:$(BACKEND_PORT)"
	@echo "DB:       localhost:$(DB_PORT)"
	@wait

## 백엔드 로컬 실행 (Docker 없이)
dev-backend-local:
	cd backend && PORT=$(BACKEND_PORT) DB_HOST=localhost DB_PORT=$(DB_PORT) DB_USER=admin DB_PASSWORD=password123 DB_NAME=company_items go run cmd/main.go

## 프론트엔드 로컬 실행 (Docker 없이)
dev-frontend-local:
	cd frontend && npm install --silent && VITE_API_URL=http://localhost:$(BACKEND_PORT) npm start

## 로컬 PostgreSQL 확인
dev-db-local:
	@/usr/local/opt/postgresql@16/bin/pg_isready -h localhost -p $(DB_PORT) > /dev/null 2>&1 \
		&& echo "DB ready on localhost:$(DB_PORT)" \
		|| (echo "Error: PostgreSQL not running. Run: brew services start postgresql@16" && exit 1)

## 백엔드만 재시작 (프론트엔드 유지)
dev-restart-backend:
	-@pkill -f "go run cmd/main.go" 2>/dev/null
	-@lsof -ti:$(BACKEND_PORT) | xargs kill 2>/dev/null || true
	@sleep 1
	$(MAKE) dev-backend-local &
	@echo "Backend restarted on localhost:$(BACKEND_PORT)"

## 로컬 개발 중지 (Docker 없이)
dev-stop-local:
	-@pkill -f "go run cmd/main.go" 2>/dev/null
	-@lsof -ti:$(BACKEND_PORT) | xargs kill 2>/dev/null || true
	-@pkill -f "vite" 2>/dev/null
	-@lsof -ti:3000 | xargs kill 2>/dev/null || true
	@sleep 1
	@echo "Stopped."

## DB 셸 (Docker 없이)
shell-db-local:
	/usr/local/opt/postgresql@16/bin/psql -h localhost -p $(DB_PORT) -U admin -d company_items

## API 테스트
test-api:
	@bash test-api.sh

## Docker 전체 실행 (docker-compose)
up:
	docker compose up --build -d
	@echo ""
	@echo "Frontend: http://localhost:3000"
	@echo "Backend:  http://localhost:8080"
	@echo "DB:       localhost:5433"

## Docker 중지
down:
	docker compose down

## Docker 중지 + 볼륨 삭제
down-v:
	docker compose down -v

## 로그 확인
logs:
	docker compose logs -f $(SVC)

# ─── Helpers ──────────────────────────────────────

.PHONY: status shell-db clean help

## K8s 상태 확인
status:
	@echo "=== Pods ==="
	@kubectl get pods -n company-items
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n company-items

## DB 셸
shell-db:
	docker exec -it company_items_db psql -U admin -d company_items

## Docker 정리 (이미지 포함)
clean:
	docker compose down -v --rmi local

## 도움말
help:
	@echo "Usage: make <target> [TAG=v1.0.0]"
	@echo ""
	@echo "Local (Docker 없이):"
	@echo "  dev-local       brew PostgreSQL + backend/frontend 전체 실행"
	@echo "  dev-backend-local 백엔드만 로컬 실행 (로컬 DB)"
	@echo "  dev-db-local    로컬 PostgreSQL 상태 확인"
	@echo "  dev-stop-local  로컬 개발 전체 중지 (Docker 없이)"
	@echo "  shell-db-local  DB 셸 (로컬 PostgreSQL)"
	@echo ""
	@echo "Local (Docker DB):"
	@echo "  dev             DB(docker) + backend/frontend(로컬) 전체 실행"
	@echo "  dev-backend     백엔드만 로컬 실행"
	@echo "  dev-frontend    프론트엔드만 로컬 실행"
	@echo "  dev-db          DB만 실행 (docker)"
	@echo "  dev-stop        로컬 개발 전체 중지"
	@echo "  test-api        API 테스트"
	@echo ""
	@echo "Docker:"
	@echo "  up              docker-compose 전체 실행"
	@echo "  down            docker-compose 중지"
	@echo "  down-v          docker-compose 중지 + 볼륨 삭제"
	@echo "  logs            로그 확인 (SVC=backend 으로 필터)"
	@echo ""
	@echo "Helpers:"
	@echo "  status        K8s 상태 확인"
	@echo "  shell-db      DB 셸 (로컬)"
	@echo "  clean         Docker 정리"
	@echo ""
	@echo "Deploy: main push 시 GitHub Actions 자동 실행"
