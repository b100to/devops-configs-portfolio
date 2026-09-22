# App Helm Chart - Quick Start Guide

5분 안에 시작하는 통합 Helm 차트 가이드

## 🚀 빠른 시작

### 1단계: Chart 확인

```bash
cd /Users/user/works/devops-configs
ls -la charts/app/
```

### 2단계: 예시 파일 확인

```bash
cat charts/app/examples/mall-v4-api-dev.yaml
```

### 3단계: 설치

```bash
helm install mall-v4-api ./charts/app \
  -f ./charts/app/examples/mall-v4-api-dev.yaml \
  -n mall-v4 \
  --create-namespace
```

## 📁 파일 구조

```
charts/app/
├── Chart.yaml              # Chart 메타데이터
├── values.yaml            # 기본 values (문서화)
├── README.md              # 상세 문서
├── CHANGELOG.md           # 변경 이력
├── MIGRATION.md           # 마이그레이션 가이드
├── TESTING.md             # 테스트 가이드
├── QUICKSTART.md          # 이 파일
├── templates/
│   ├── _helpers.tpl       # Helper 함수
│   ├── namespace.yaml     # Namespace
│   ├── serviceaccount.yaml # Service Account
│   ├── deployment.yaml    # Deployment
│   ├── service.yaml       # Service
│   └── hpa.yaml          # HPA
└── examples/
    ├── mall-v4-api-dev.yaml
    ├── venue-beacon-api-dev.yaml
    └── mall-v3-worker-dev.yaml
```

## 🎯 주요 기능

- ✅ **통합 차트**: 하나의 차트로 모든 애플리케이션 관리
- ✅ **Namespace 관리**: 자동 생성 및 레이블링
- ✅ **Service Account**: IAM Role 연동
- ✅ **External Secrets**: AWS Secrets Manager 연동
- ✅ **Datadog 통합**: APM, 로그 자동 설정
- ✅ **AWS 통합**: 자격 증명, ECR 자동 설정
- ✅ **Health Check**: HTTP, TCP, Exec 지원
- ✅ **Autoscaling**: HPA 완벽 지원

## 📝 기본 Values 템플릿

```yaml
# 필수 설정
global:
  env: dev
  registry:
    accountId: "111111111111"
    region: "ap-northeast-2"

fullnameOverride: my-app

image:
  repository: my-app-repo
  tag: latest

service:
  enabled: true
  port: 8080

# 선택 설정
namespace:
  name: my-namespace

serviceAccount:
  create: true
  name: my-sa

resources:
  requests:
    cpu: 50m
    memory: 512Mi
  limits:
    memory: 512Mi

aws:
  enabled: true

datadog:
  enabled: true

# External Secrets (선택)
externalSecret:
  enabled: true
  secrets:
    - name: aws-credentials
      target:
        name: aws-account
      data:
        - secretKey: AWS_ACCESS_KEY_ID
          remoteRef:
            key: eks/my-cluster
            property: AWS_ACCESS_KEY_ID
```

## 🔧 자주 사용하는 명령어

### 설치
```bash
helm install <name> ./charts/app -f <values> -n <namespace>
```

### 업그레이드
```bash
helm upgrade <name> ./charts/app -f <values> -n <namespace>
```

### 상태 확인
```bash
helm status <name> -n <namespace>
```

### 삭제
```bash
helm uninstall <name> -n <namespace>
```

### Dry-run
```bash
helm install <name> ./charts/app -f <values> -n <namespace> --dry-run --debug
```

## 🎓 학습 순서

1. **README.md** - 전체 개요 및 기능 설명
2. **examples/** - 실제 사용 예시
3. **MIGRATION.md** - 기존 차트에서 마이그레이션
4. **TESTING.md** - 테스트 및 검증
5. **values.yaml** - 모든 설정 옵션

## 💡 실전 예시

### Mall v4 API

```bash
helm install mall-v4-api ./charts/app \
  -f ./values/apps/mall/v4/api/dev.yaml \
  -n mall-v4 \
  --create-namespace
```

### Venue Beacon API

```bash
helm install beacon-api ./charts/app \
  -f ./values/apps/venue/beacon-api/dev.yaml \
  -n venue \
  --create-namespace
```

### 이미지 태그 변경

```bash
helm upgrade mall-v4-api ./charts/app \
  -f ./values/apps/mall/v4/api/dev.yaml \
  --set image.tag=v1.2.3 \
  -n mall-v4
```

## 🐛 트러블슈팅

### 이미지를 찾을 수 없음
```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin 111111111111.dkr.ecr.ap-northeast-2.amazonaws.com
```

### Service Account가 이미 존재
```yaml
serviceAccount:
  create: false  # 기존 SA 사용
  name: existing-sa
```

### Namespace가 이미 존재
```yaml
namespace:
  create: false  # 기존 namespace 사용
  name: existing-namespace
```

## 📚 더 알아보기

- **전체 문서**: [README.md](README.md)
- **마이그레이션**: [MIGRATION.md](MIGRATION.md)
- **테스트**: [TESTING.md](TESTING.md)
- **변경 이력**: [CHANGELOG.md](CHANGELOG.md)

## 🤝 도움이 필요하신가요?

1. README.md의 해당 섹션 확인
2. examples/ 디렉토리의 예시 확인
3. GitHub Issues 생성
4. DevOps 팀에 문의

---

**행복한 배포 되세요! 🚢**
