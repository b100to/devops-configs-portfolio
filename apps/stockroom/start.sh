#!/bin/bash

# 회사 물품 신청 시스템 실행 스크립트

echo "🚀 회사 물품 신청 시스템을 시작합니다..."

# Docker 실행 상태 확인
if ! docker --version > /dev/null 2>&1; then
    echo "❌ Docker가 설치되어 있지 않습니다."
    exit 1
fi

if ! docker-compose --version > /dev/null 2>&1; then
    echo "❌ Docker Compose가 설치되어 있지 않습니다."
    exit 1
fi

# 기존 컨테이너 정리
echo "🧹 기존 컨테이너를 정리합니다..."
docker-compose down -v 2>/dev/null || true

# 컨테이너 빌드 및 실행
echo "🏗️  시스템을 빌드하고 실행합니다..."
docker-compose up --build -d

# 서비스 상태 확인
echo "⏳ 서비스가 준비될 때까지 기다립니다..."
sleep 45

# 헬스체크
echo "🔍 서비스 상태를 확인합니다..."

# PostgreSQL 헬스체크
if docker exec company_items_db pg_isready -U admin -d company_items > /dev/null 2>&1; then
    echo "✅ PostgreSQL 데이터베이스가 준비되었습니다."
else
    echo "❌ PostgreSQL 데이터베이스 연결에 실패했습니다."
fi

# 백엔드 헬스체크
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ Go 백엔드 API가 준비되었습니다."
else
    echo "❌ Go 백엔드 API 연결에 실패했습니다."
fi

# 프론트엔드 헬스체크
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo "✅ React 프론트엔드가 준비되었습니다."
else
    echo "❌ React 프론트엔드 연결에 실패했습니다."
fi

echo ""
echo "🎉 시스템이 성공적으로 시작되었습니다!"
echo ""
echo "📍 접속 정보:"
echo "   - 사용자 페이지: http://localhost:3000"
echo "   - 관리자 페이지: http://localhost:3000/admin"
echo "   - API 문서: http://localhost:8080/health"
echo ""
echo "🛑 시스템을 중지하려면: docker-compose down"
echo "📊 로그를 보려면: docker-compose logs -f"
echo ""
echo "📋 샘플 사용자 정보:"
echo "   - 이름: 김철수, 별명: 철수"
echo "   - 이름: 이영희, 별명: 영희"
echo "   - 이름: 박민수, 별명: 민수"