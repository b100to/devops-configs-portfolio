# ArgoCD 앱 배포 워크플로우

ArgoCD를 사용한 Kubernetes 애플리케이션 배포를 전문으로 합니다.

## 주요 책임

1. **기존 패턴 분석**
   - `argocd/` 폴더의 기존 AppProject 및 Application 정의 패턴 파악
   - `values/` 폴더의 기존 values 파일 구조 이해
   - dev/prd 환경별 차이점 확인

2. **새 애플리케이션 배포 준비**
   - ArgoCD AppProject 또는 Application 매니페스트 생성
   - 적절한 values 파일 생성 (dev, prd 환경별)
   - namespace, service 이름 등을 일관되게 설정

3. **검증 및 베스트 프랙티스**
   - YAML 문법 검증
   - 기존 레포지토리의 명명 규칙 준수
   - 리소스 요청/제한 설정 포함 여부 확인
   - 보안 설정 (NetworkPolicy, RBAC 등) 고려

## 작업 프로세스

### 단계 1: 정보 수집
다음 정보를 확인합니다:
- 애플리케이션/오픈소스 이름
- Helm chart 저장소 URL (있는 경우)
- 대상 환경 (dev, prd, 또는 둘 다)
- 배포할 namespace
- 애플리케이션 카테고리 (apps or infra)

### 단계 2: 기존 패턴 참고
```bash
# 기존 ArgoCD 설정 확인
ls -R argocd/

# 기존 values 파일 확인
ls -R values/

# 유사한 앱의 설정을 읽어 패턴 파악
```

### 단계 3: 파일 생성

**App of Apps 구조 이해**:
- `root-app-v2` (Terraform으로 생성): `argocd/{env}/` 디렉토리를 모니터링
- Application 파일을 `argocd/{env}/apps/` 또는 `infra/`에 추가하면 자동 배포
- **Terraform 재실행 불필요!**

1. **ArgoCD Application 생성** (필수)
   - 경로:
     - 애플리케이션 서비스: `argocd/{env}/apps/{app-name}.yaml`
     - 인프라 서비스: `argocd/{env}/infra/{app-name}.yaml`

2. **Values 파일 생성** (Helm chart 사용 시)
   - 경로: `values/{apps|infra}/{service-name}/{env}.yaml`
   - **중요**: 최소 필수 항목만 먼저 작성

3. **ArgoCD AppProject 생성** (필요한 경우만)
   - 경로: `argocd/{env}/proj/{project-name}.yaml`
   - 대부분 기존 프로젝트 재사용 가능

### Values 파일 작성 가이드

**원칙: 간결하게 시작, 점진적으로 확장**

#### 필수 항목만 포함 (첫 배포)
```yaml
# values/apps/my-service/dev.yaml
image:
  repository: <registry>/my-service
  tag: "1.0.0"
  pullPolicy: IfNotPresent

resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 512Mi
    cpu: 200m

service:
  port: 8080
```

#### 환경별 차이가 있는 경우 추가
```yaml
# dev.yaml - 개발 환경
replicaCount: 1
resources:
  limits:
    memory: 512Mi

# prd.yaml - 프로덕션 환경
replicaCount: 3
resources:
  limits:
    memory: 2Gi
```

## 베스트 프랙티스

### 명명 규칙
- Application 이름: kebab-case (예: `my-service`)
- namespace: kebab-case 또는 도메인별 구분
- labels: 일관된 key-value 사용

### 리소스 관리
- 항상 resources.requests와 resources.limits 설정
- 프로덕션은 개발보다 높은 리소스 할당
- HPA/VPA 설정 고려

### 보안
- 민감 정보는 External Secrets Operator 사용
- NetworkPolicy로 트래픽 제한
- RBAC 최소 권한 원칙 준수

### 모니터링
- Prometheus ServiceMonitor 설정
- 적절한 healthcheck (liveness/readiness) 설정
- 로그 수집 고려

## 문제 해결

### Application이 배포되지 않을 때
1. ArgoCD UI에서 Application 상태 확인
2. Sync 상태 및 에러 메시지 확인
3. values 파일의 문법 오류 확인
4. Helm chart 버전 호환성 확인

### Values 오버라이드가 안될 때
- Application의 `values` 경로가 올바른지 확인
- values 파일 내 YAML 들여쓰기 확인
- Helm chart의 기본 values.yaml과 비교
