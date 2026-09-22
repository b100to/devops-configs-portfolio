#!/bin/bash

# 개발 모드 실행 스크립트

echo "🚀 개발 모드로 시스템을 시작합니다..."

# 필요한 도구 확인
if ! go version > /dev/null 2>&1; then
    echo "❌ Go가 설치되어 있지 않습니다."
    exit 1
fi

if ! node --version > /dev/null 2>&1; then
    echo "❌ Node.js가 설치되어 있지 않습니다."
    exit 1
fi

# 데이터베이스만 Docker로 실행
echo "🗄️  PostgreSQL 데이터베이스를 시작합니다..."
docker-compose up -d postgres

echo "⏳ 데이터베이스가 준비될 때까지 기다립니다..."
sleep 10

# 백엔드 의존성 설치
echo "📦 Go 백엔드 의존성을 설치합니다..."
cd backend
go mod download

# 백엔드 실행 (백그라운드)
echo "🔧 Go 백엔드를 시작합니다..."
DB_HOST=localhost go run cmd/main.go &
BACKEND_PID=$!

# 프론트엔드 의존성 설치
echo "📦 React 프론트엔드 의존성을 설치합니다..."
cd ../frontend
npm install

# 프론트엔드 실행
echo "💻 React 프론트엔드를 시작합니다..."
REACT_APP_API_URL=http://localhost:8080 npm start &
FRONTEND_PID=$!

echo ""
echo "🎉 개발 환경이 시작되었습니다!"
echo ""
echo "📍 접속 정보:"
echo "   - 프론트엔드: http://localhost:3000"
echo "   - 백엔드 API: http://localhost:8080"
echo "   - 데이터베이스: localhost:5432"
echo ""
echo "🛑 종료하려면 Ctrl+C를 누르세요"

# 정리 함수
cleanup() {
    echo ""
    echo "🧹 프로세스를 정리합니다..."
    kill $BACKEND_PID 2>/dev/null
    kill $FRONTEND_PID 2>/dev/null
    docker-compose down
    exit 0
}

# 신호 핸들러 등록
trap cleanup SIGINT SIGTERM

# 대기
wait