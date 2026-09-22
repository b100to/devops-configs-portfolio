# Chart 검증 스크립트

이 스크립트들을 사용하여 차트를 검증할 수 있습니다.

## 1. Helm Lint

```bash
helm lint charts/app
helm lint charts/app -f charts/app/examples/mall-v4-api-dev.yaml
helm lint charts/app -f charts/app/examples/venue-beacon-api-dev.yaml
helm lint charts/app -f charts/app/examples/mall-v3-worker-dev.yaml
```

## 2. Template 렌더링 테스트

```bash
# 기본 values로 렌더링
helm template test-app charts/app

# Mall v4 API 렌더링
helm template mall-v4-api charts/app -f charts/app/examples/mall-v4-api-dev.yaml

# Venue Beacon API 렌더링
helm template beacon-api charts/app -f charts/app/examples/venue-beacon-api-dev.yaml

# Mall v3 Worker 렌더링
helm template mall-v3-worker charts/app -f charts/app/examples/mall-v3-worker-dev.yaml
```

## 3. Dry-run 설치 테스트

```bash
# Mall v4 API
helm install mall-v4-api charts/app \
  -f charts/app/examples/mall-v4-api-dev.yaml \
  -n mall-v4 \
  --create-namespace \
  --dry-run --debug

# Venue Beacon API
helm install beacon-api charts/app \
  -f charts/app/examples/venue-beacon-api-dev.yaml \
  -n venue \
  --create-namespace \
  --dry-run --debug

# Mall v3 Worker
helm install mall-v3-worker charts/app \
  -f charts/app/examples/mall-v3-worker-dev.yaml \
  -n mall-v3 \
  --create-namespace \
  --dry-run --debug
```

## 4. 실제 설치

```bash
# Mall v4 API 설치
helm install mall-v4-api charts/app \
  -f values/apps/mall/v4/api/dev.yaml \
  -n mall-v4 \
  --create-namespace

# 상태 확인
helm status mall-v4-api -n mall-v4
kubectl get all -n mall-v4

# Venue Beacon API 설치
helm install beacon-api charts/app \
  -f values/apps/venue/beacon-api/dev.yaml \
  -n venue \
  --create-namespace

# 상태 확인
helm status beacon-api -n venue
kubectl get all -n venue
```

## 5. 업그레이드

```bash
# 이미지 태그 변경
helm upgrade mall-v4-api charts/app \
  -f values/apps/mall/v4/api/dev.yaml \
  --set image.tag=v1.2.3 \
  -n mall-v4

# values 파일 수정 후 업그레이드
helm upgrade mall-v4-api charts/app \
  -f values/apps/mall/v4/api/dev.yaml \
  -n mall-v4
```

## 6. 롤백

```bash
# 이전 버전으로 롤백
helm rollback mall-v4-api -n mall-v4

# 특정 버전으로 롤백
helm rollback mall-v4-api 2 -n mall-v4
```

## 7. 삭제

```bash
# 릴리스 삭제
helm uninstall mall-v4-api -n mall-v4

# 네임스페이스도 함께 삭제
helm uninstall mall-v4-api -n mall-v4
kubectl delete namespace mall-v4
```

## 8. Chart 패키징

```bash
# Chart를 tgz 파일로 패키징
helm package charts/app

# 버전 지정
helm package charts/app --version 1.0.0 --app-version 1.0.0
```

## 9. 디버깅

```bash
# 렌더링된 매니페스트 확인
helm get manifest mall-v4-api -n mall-v4

# 사용된 values 확인
helm get values mall-v4-api -n mall-v4

# 모든 정보 확인
helm get all mall-v4-api -n mall-v4

# Release 히스토리
helm history mall-v4-api -n mall-v4
```

## 10. 모든 애플리케이션 일괄 배포 스크립트

```bash
#!/bin/bash

# Mall v4 애플리케이션들
MALL_V4_APPS=("api" "api-admin" "consumer" "seller")
for app in "${MALL_V4_APPS[@]}"; do
  echo "Installing mall-v4-$app..."
  helm upgrade --install "mall-v4-$app" charts/app \
    -f "values/apps/mall/v4/$app/dev.yaml" \
    -n mall-v4 \
    --create-namespace
done

# Mall v3 애플리케이션들
MALL_V3_APPS=("api" "worker" "beat" "excel-worker")
for app in "${MALL_V3_APPS[@]}"; do
  echo "Installing mall-v3-$app..."
  helm upgrade --install "mall-v3-$app" charts/app \
    -f "values/apps/mall/v3/$app/dev.yaml" \
    -n mall-v3 \
    --create-namespace
done

# Venue 애플리케이션들
VENUE_APPS=("beacon-api" "ins-api" "member-api" "play-api" "user-api")
for app in "${VENUE_APPS[@]}"; do
  echo "Installing $app..."
  helm upgrade --install "$app" charts/app \
    -f "values/apps/venue/$app/dev.yaml" \
    -n venue \
    --create-namespace
done

echo "All applications deployed!"
```
