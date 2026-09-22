# 회사 물품 신청 시스템

회사에서 제공하는 물품을 신청하기 위한 웹 애플리케이션입니다.

## 기술 스택

- **백엔드**: Go (Gin framework)
- **프론트엔드**: React + TypeScript
- **데이터베이스**: PostgreSQL
- **배포**: Docker & Docker Compose

## 기능

### 사용자 기능
- 이름/별명으로 회사 정보 자동 입력
- 물품 목록 조회
- 물품 신청 (수량 선택)

### 관리자 기능
- 물품 추가/삭제
- 물품 수량 관리
- 신청 내역 조회

## 실행 방법

```bash
# Docker Compose로 전체 시스템 실행
docker-compose up -d

# 개발 모드로 실행
cd backend && go run cmd/main.go
cd frontend && npm start
```

## API 엔드포인트

- `GET /api/users/{name}` - 사용자 정보 조회
- `GET /api/items` - 물품 목록 조회
- `POST /api/requests` - 물품 신청
- `GET /api/admin/requests` - 신청 내역 조회 (관리자)
- `POST /api/admin/items` - 물품 추가 (관리자)
- `PUT /api/admin/items/{id}` - 물품 수정 (관리자)
- `DELETE /api/admin/items/{id}` - 물품 삭제 (관리자)