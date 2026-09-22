# API 테스트 스크립트

# 1. 헬스체크
echo "=== 헬스체크 ==="
curl -s http://localhost:8080/health | jq .

echo -e "\n=== 사용자 검색 테스트 ==="
# 2. 사용자 검색
curl -s http://localhost:8080/api/users/철수 | jq .
curl -s http://localhost:8080/api/users/김철수 | jq .

echo -e "\n=== 물품 목록 조회 ==="
# 3. 물품 목록 조회
curl -s http://localhost:8080/api/items | jq .

echo -e "\n=== 카테고리 목록 조회 ==="
# 4. 카테고리 목록 조회
curl -s http://localhost:8080/api/categories | jq .

echo -e "\n=== 물품 신청 테스트 ==="
# 5. 물품 신청 테스트
curl -X POST http://localhost:8080/api/requests \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "item_id": 1,
    "quantity": 2,
    "notes": "테스트 신청입니다"
  }' | jq .

echo -e "\n=== 관리자 - 신청 내역 조회 ==="
# 6. 신청 내역 조회
curl -s http://localhost:8080/api/admin/requests | jq .

echo -e "\n=== 관리자 - 새 물품 추가 ==="
# 7. 새 물품 추가 테스트
curl -X POST http://localhost:8080/api/admin/items \
  -H "Content-Type: application/json" \
  -d '{
    "name": "테스트 물품",
    "description": "API 테스트용 물품입니다",
    "category_id": 1,
    "available_quantity": 10,
    "max_per_user": 2,
    "image_url": "/images/test-item.jpg"
  }' | jq .