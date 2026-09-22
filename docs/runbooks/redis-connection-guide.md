# Redis 연결 가이드 (IntelliJ Ultimate)

이 문서는 IntelliJ Ultimate의 Database 도구를 사용하여 Kubernetes 클러스터의 Redis에 연결하는 방법을 설명합니다.

---

## 사전 준비

- IntelliJ IDEA Ultimate 버전
- kubectl 설치 및 클러스터 접근 권한
- Redis 프록시 배포 완료

---

## Redis 프록시 배포

### 1. Mall Redis 배포
```bash
kubectl apply -f manifests/redis/dev/mall.yaml
```

**연결 정보:**
- Service: `mall-redis-service`
- Port: `6379`
- 엔드포인트: `acmemall-alpha-cache-redis-001.ghijkl.0001.apn2.cache.amazonaws.com:6379`

### 2. Venue Redis 배포
```bash
kubectl apply -f manifests/redis/dev/venue.yaml
```

**연결 정보:**
- Service: `venue-redis-service`
- Port: `6379`
- 엔드포인트: `acme-redis-003.ghijkl.0001.apn2.cache.amazonaws.com:6379`

---

## IntelliJ에서 Redis 연결하기

### 방법 1: 개별 연결 (하나씩 사용)

#### Mall Redis 연결

**1단계: 포트포워딩**
```bash
kubectl port-forward service/mall-redis-service 6379:6379
```

**2단계: IntelliJ Database 설정**
1. IntelliJ 우측 **Database** 탭 클릭
2. `+` → **Data Source** → **Redis** 선택
3. 연결 정보 입력:
   ```
   Name: Mall Redis (Dev)
   Host: localhost
   Port: 6379
   Authentication: None
   Database: 0
   ```
4. **Download missing driver files** 클릭 (최초 1회)
5. **Test Connection** → "Successful" 확인
6. **OK** 클릭

#### Venue Redis 연결

**1단계: 포트포워딩**
```bash
kubectl port-forward service/venue-redis-service 6379:6379
```

**2단계: IntelliJ Database 설정**
1. IntelliJ 우측 **Database** 탭 클릭
2. `+` → **Data Source** → **Redis** 선택
3. 연결 정보 입력:
   ```
   Name: Venue Redis (Dev)
   Host: localhost
   Port: 6379
   Authentication: None
   Database: 0
   ```
4. **Test Connection** → "Successful" 확인
5. **OK** 클릭

---

### 방법 2: 동시 연결 (두 개 모두 사용)

두 Redis를 동시에 사용하려면 서로 다른 로컬 포트를 사용해야 합니다.

#### 1단계: 포트포워딩 (각각 다른 터미널에서 실행)

**터미널 1 - Mall Redis:**
```bash
kubectl port-forward service/mall-redis-service 6379:6379
```

**터미널 2 - Venue Redis:**
```bash
kubectl port-forward service/venue-redis-service 6380:6379
```

#### 2단계: IntelliJ Database 설정

**Mall Redis:**
```
Name: Mall Redis (Dev)
Host: localhost
Port: 6379
Authentication: None
Database: 0
```

**Venue Redis:**
```
Name: Venue Redis (Dev)
Host: localhost
Port: 6380  ← 주의: 6380 사용
Authentication: None
Database: 0
```

---

## Redis 사용하기

### Console에서 명령어 실행

1. Database 탭에서 Redis 연결 확장
2. **console** 아이콘 (또는 우클릭 → **Jump to Console**) 클릭
3. Redis 명령어 실행:

```redis
# 모든 키 조회
KEYS *

# 특정 패턴 키 조회
KEYS user:*

# 값 조회
GET some_key

# 값 설정
SET test_key "test_value"

# TTL 확인
TTL some_key

# 데이터 타입 확인
TYPE some_key

# Hash 조회
HGETALL hash_key

# List 조회
LRANGE list_key 0 -1

# Set 조회
SMEMBERS set_key
```

### 데이터 탐색

- Database 탭에서 Redis 연결을 확장하면 키 목록이 표시됩니다
- 키를 더블클릭하면 값을 확인할 수 있습니다
- 우클릭으로 삭제, 수정 등의 작업이 가능합니다

---

## 문제 해결

### 연결 실패 시

**1. 포트포워딩 확인**
```bash
# 실행 중인 포트포워딩 확인
ps aux | grep "port-forward"

# 포트 사용 확인
lsof -i :6379
lsof -i :6380
```

**2. 프록시 Pod 상태 확인**
```bash
# Mall Redis
kubectl get pod -l app=mall-redis-proxy
kubectl logs -l app=mall-redis-proxy

# Venue Redis
kubectl get pod -l app=venue-redis-proxy
kubectl logs -l app=venue-redis-proxy
```

**3. Service 확인**
```bash
kubectl get service mall-redis-service
kubectl get service venue-redis-service
```

### "Connection refused" 에러

- 포트포워딩이 실행 중인지 확인
- `localhost` 대신 `127.0.0.1` 시도
- 방화벽 설정 확인

### Driver 다운로드 실패

- IntelliJ Settings → Build, Execution, Deployment → Database → User Drivers
- Redis driver 수동 다운로드 및 추가

---

## 클러스터 내부에서 접근 (애플리케이션)

애플리케이션 코드에서는 포트포워딩 없이 Service 이름으로 직접 접근:

**Mall Redis:**
```
REDIS_HOST=mall-redis-service
REDIS_PORT=6379
```

**Venue Redis:**
```
REDIS_HOST=venue-redis-service
REDIS_PORT=6379
```

---

## 보안 주의사항

- 포트포워딩은 개발/디버깅 용도로만 사용
- 프로덕션 환경에서는 보안 정책에 따라 접근 제어
- 민감한 데이터를 Redis에 저장할 때는 암호화 고려
- 불필요한 포트포워딩은 즉시 종료

---

## 참고

- [Redis 프록시 설정 - Mall](../../manifests/redis/dev/mall.yaml)
- [Redis 프록시 설정 - Venue](../../manifests/redis/dev/venue.yaml)
- [MySQL 연결 가이드](../../manifests/mysql/dev/mall.yaml)
