# App Helm Chart

통합 애플리케이션 Helm 차트입니다. Mall v3, Mall v4, Venue 등 모든 애플리케이션 워크로드를 지원합니다.

## 주요 특징

- ✅ **통합 차트**: 모든 애플리케이션을 하나의 차트로 관리
- ✅ **Namespace 관리**: 네임스페이스 자동 생성 지원
- ✅ **Service Account**: IAM Role 연동을 위한 Service Account 생성 지원
- ✅ **Datadog 통합**: Datadog APM, 로그 자동 연동
- ✅ **AWS 통합**: AWS 자격 증명, 리전 설정 지원
- ✅ **유연한 설정**: Health Check, Resources, Autoscaling 등 모든 설정 커스터마이징
- ✅ **스케줄링**: Node Selector, Affinity, Tolerations, Topology Spread 지원

## Chart 구조

```
app/
├── Chart.yaml                    # Chart 메타데이터
├── values.yaml                   # 기본 values (모든 옵션 문서화)
├── templates/
│   ├── _helpers.tpl             # Helper 함수들
│   ├── namespace.yaml           # Namespace 생성
│   ├── serviceaccount.yaml      # Service Account 생성
│   ├── deployment.yaml          # Deployment
│   ├── service.yaml             # Service
│   └── hpa.yaml                 # HorizontalPodAutoscaler
└── examples/                     # 실제 사용 예시
    ├── mall-v4-api-dev.yaml
    ├── venue-beacon-api-dev.yaml
    └── mall-v3-worker-dev.yaml
```

## 빠른 시작

### 1. 기본 설치

```bash
helm install my-app ./charts/app \
  --values ./charts/app/examples/mall-v4-api-dev.yaml
```

### 2. 네임스페이스 지정

```bash
helm install my-app ./charts/app \
  --values ./charts/app/examples/mall-v4-api-dev.yaml \
  --namespace mall-v4 \
  --create-namespace
```

### 3. 특정 값 오버라이드

```bash
helm install my-app ./charts/app \
  --values ./charts/app/examples/mall-v4-api-dev.yaml \
  --set image.tag=v1.2.3 \
  --set replicaCount=3
```

## 설정 가이드

### 기본 설정

```yaml
global:
  env: dev
  registry:
    accountId: "111111111111"
    region: "ap-northeast-2"

fullnameOverride: my-app

image:
  repository: my-app-repo
  tag: latest
  pullPolicy: IfNotPresent

replicaCount: 1
```

### Namespace 생성

```yaml
namespace:
  create: true
  name: my-namespace
  labels:
    env: dev
  annotations:
    description: "My application namespace"
```

### Service Account 설정

Service Account를 생성하고 IAM Role과 연동:

```yaml
serviceAccount:
  create: true
  name: app-mall
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-app-role
```

### Image 설정

#### ECR 사용 (권장)

```yaml
global:
  registry:
    accountId: "111111111111"
    region: "ap-northeast-2"

image:
  repository: acmemall-backend-v4/dev/api
  tag: v1.2.3
```

실제 이미지: `111111111111.dkr.ecr.ap-northeast-2.amazonaws.com/acmemall-backend-v4/dev/api:v1.2.3`

#### 다른 레지스트리 사용

```yaml
image:
  registry: docker.io
  repository: myorg/myapp
  tag: v1.2.3
```

### Service 설정

```yaml
service:
  enabled: true
  type: ClusterIP
  port: 8080
  targetPort: 8080
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

### 레이블 설정

이 차트는 [Kubernetes 권장 레이블](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)을 자동으로 적용합니다.

#### 자동으로 추가되는 레이블

```yaml
app.kubernetes.io/name: <fullname>           # 애플리케이션 이름
app.kubernetes.io/instance: <release-name>   # 릴리스 인스턴스 이름
app.kubernetes.io/version: <chart-version>   # 애플리케이션 버전
app.kubernetes.io/managed-by: Helm           # 관리 도구
```

#### 추가 권장 레이블 설정

```yaml
# 아키텍처 내 구성요소 지정 (예: database, cache, frontend, backend, api, worker)
appComponent: backend

# 이 애플리케이션이 속한 전체 시스템 이름 (예: mall-system, venue-system)
appPartOf: mall-system
```

적용 결과:
```yaml
app.kubernetes.io/component: backend
app.kubernetes.io/part-of: mall-system
```

#### 커스텀 레이블 추가

리소스 레벨에 추가 레이블:
```yaml
labels:
  team: backend
  cost-center: engineering
```

Pod 레벨에만 추가 레이블:
```yaml
podLabels:
  version: stable
  feature: new-payment
```

#### 레이블 활용 예시

모든 레이블이 적용된 설정:
```yaml
fullnameOverride: mall-api
appComponent: api
appPartOf: mall-system

labels:
  team: backend-team
  environment: production

podLabels:
  feature: payment-v2
```

최종 생성되는 레이블:
```yaml
# 모든 리소스에 적용
app.kubernetes.io/name: mall-api
app.kubernetes.io/instance: mall-api-release
app.kubernetes.io/version: "1.0.0"
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/component: api
app.kubernetes.io/part-of: mall-system
team: backend-team
environment: production

# Pod에만 추가로 적용
feature: payment-v2
```

### Health Check 설정

#### HTTP Health Check (Spring Boot Actuator)

```yaml
livenessProbe:
  enabled: true
  httpGet:
    path: /actuator/health/liveness
    port: http
  initialDelaySeconds: 5
  periodSeconds: 15

readinessProbe:
  enabled: true
  httpGet:
    path: /actuator/health/readiness
    port: http
  initialDelaySeconds: 5
  periodSeconds: 15

startupProbe:
  enabled: true
  httpGet:
    path: /actuator/health/liveness
    port: http
  periodSeconds: 10
  failureThreshold: 30
```

#### TCP Health Check

```yaml
livenessProbe:
  enabled: true
  tcpSocket:
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 30

readinessProbe:
  enabled: true
  tcpSocket:
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 30
```

#### Command Health Check

```yaml
livenessProbe:
  enabled: true
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 10
```

### Resources 설정

```yaml
resources:
  requests:
    cpu: 100m
    memory: 512Mi
  limits:
    memory: 512Mi
```

### Autoscaling 설정

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
```

### Environment Variables

#### 일반 환경 변수

```yaml
env:
  - name: SPRING_PROFILES_ACTIVE
    value: dev
  - name: LOG_LEVEL
    value: info
```

#### Secret에서 가져오기

```yaml
env:
  - name: DATABASE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: password
```

#### ConfigMap에서 가져오기

```yaml
envFrom:
  - configMapRef:
      name: app-config
  - secretRef:
      name: app-secret
```

### AWS 설정

```yaml
aws:
  enabled: true
  region: ap-northeast-2
  credentials:
    fromSecret: true
    secretName: aws-account
    accessKeyIdKey: AWS_ACCESS_KEY_ID
    secretAccessKeyKey: AWS_SECRET_ACCESS_KEY
```

이렇게 하면 다음 환경 변수가 자동으로 추가됩니다:
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID` (from Secret)
- `AWS_SECRET_ACCESS_KEY` (from Secret)

### Datadog 설정

```yaml
datadog:
  enabled: true
  version: v4
  logsInjection: "true"
  traceSampleRate: "0.1"

podAnnotations:
  admission.datadoghq.com/java-lib.version: "v1.37.1"
```

이렇게 하면:
- Datadog APM이 활성화됩니다
- 자동으로 `/var/run/datadog` 볼륨이 마운트됩니다
- 필요한 환경 변수들이 자동으로 추가됩니다

### Scheduling

#### Node Selector

```yaml
nodeSelector:
  karpenter.sh/nodepool: mall-v4
```

#### Tolerations

```yaml
tolerations:
  - key: node-group-type
    operator: Equal
    value: mall-v4
    effect: NoSchedule
```

#### Affinity

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: karpenter.sh/nodepool
          operator: In
          values: ["service"]
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: my-app
        topologyKey: kubernetes.io/hostname
```

#### Topology Spread Constraints

```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: my-app
```

### Volumes

```yaml
volumeMounts:
  - name: config
    mountPath: /etc/config
    readOnly: true
  - name: cache
    mountPath: /tmp/cache

volumes:
  - name: config
    configMap:
      name: my-config
  - name: cache
    emptyDir: {}
```

### External Secrets

AWS Secrets Manager에서 시크릿을 자동으로 가져와 Kubernetes Secret으로 생성합니다.

> **전제 조건**: ClusterSecretStore `aws-secrets-store`가 이미 클러스터에 존재해야 합니다.
> 
> ```bash
> # ClusterSecretStore는 클러스터에 한 번만 생성하면 됩니다
> kubectl apply -f manifests/external-secrets/dev/common.yaml
> ```

#### 단일 시크릿

```yaml
externalSecret:
  enabled: true
  secrets:
    - name: aws-credentials
      refreshInterval: "15m"
      secretStoreRef:
        name: aws-secrets-store
        kind: ClusterSecretStore
      target:
        name: aws-account
        creationPolicy: Owner
      data:
        - secretKey: AWS_ACCESS_KEY_ID
          remoteRef:
            key: eks/acme-main-dev
            property: AWS_ACCESS_KEY_ID
        - secretKey: AWS_SECRET_ACCESS_KEY
          remoteRef:
            key: eks/acme-main-dev
            property: AWS_SECRET_ACCESS_KEY

# External Secret으로 생성된 Secret 사용
aws:
  enabled: true
  credentials:
    fromSecret: true
    secretName: aws-account
```

#### 여러 개의 시크릿

```yaml
externalSecret:
  enabled: true
  secrets:
    # AWS Credentials
    - name: aws-credentials
      target:
        name: aws-secret
      data:
        - secretKey: AWS_ACCESS_KEY_ID
          remoteRef:
            key: eks/my-cluster
            property: AWS_ACCESS_KEY_ID
    
    # Database Credentials
    - name: db-credentials
      target:
        name: db-secret
      data:
        - secretKey: DB_PASSWORD
          remoteRef:
            key: eks/my-cluster
            property: DB_PASSWORD
    
    # Application Secrets
    - name: app-secrets
      target:
        name: app-secret
      data:
        - secretKey: API_KEY
          remoteRef:
            key: eks/my-cluster
            property: API_KEY

# envFrom으로 모든 시크릿 주입
envFrom:
  - secretRef:
      name: aws-secret
  - secretRef:
      name: db-secret
  - secretRef:
      name: app-secret
```

#### dataFrom 사용 (전체 시크릿 가져오기)

```yaml
externalSecret:
  enabled: true
  secrets:
    - name: all-secrets
      target:
        name: all-secrets
      dataFrom:
        - extract:
            key: eks/my-cluster
```

#### 완전한 예시 (ExternalSecret + AWS 연동)

```yaml
externalSecret:
  enabled: true
  secrets:
    - name: aws-credentials
      refreshInterval: "15m"
      secretStoreRef:
        name: aws-secrets-store
        kind: ClusterSecretStore
      target:
        name: aws-account
      data:
        - secretKey: AWS_ACCESS_KEY_ID
          remoteRef:
            key: eks/acme-main-dev
            property: AWS_ACCESS_KEY_ID
        - secretKey: AWS_SECRET_ACCESS_KEY
          remoteRef:
            key: eks/acme-main-dev
            property: AWS_SECRET_ACCESS_KEY

# 생성된 Secret 사용
aws:
  enabled: true
  credentials:
    fromSecret: true
    secretName: aws-account
```

## 실제 사용 예시

### Mall v4 API

```yaml
global:
  env: dev
  registry:
    accountId: "111111111111"
    region: "ap-northeast-2"

fullnameOverride: mall-v4-api
namespace:
  name: mall-v4

image:
  repository: acmemall-backend-v4/dev/api
  tag: latest

serviceAccount:
  create: true
  name: app-mall

service:
  port: 8080

livenessProbe:
  httpGet:
    path: /actuator/health/liveness

readinessProbe:
  httpGet:
    path: /actuator/health/readiness

resources:
  requests:
    cpu: 50m
    memory: 900Mi
  limits:
    memory: 900Mi

aws:
  enabled: true

datadog:
  enabled: true
  version: v4
```

### Venue Beacon API

```yaml
global:
  env: dev
  registry:
    accountId: "111111111111"
    region: "ap-northeast-2"

fullnameOverride: beacon-api
namespace:
  name: venue

image:
  repository: micro-beacon-service-dev
  tag: latest

serviceAccount:
  create: true
  name: app-venue

priorityClassName: high-priority

service:
  port: 8879

livenessProbe:
  httpGet:
    path: /

resources:
  requests:
    cpu: 15m
    memory: 500Mi
  limits:
    memory: 500Mi

env:
  - name: SPRING_PROFILES_ACTIVE
    value: dev

aws:
  enabled: true

datadog:
  enabled: false
```

## Helm 명령어

### 설치

```bash
helm install <release-name> ./charts/app -f <values-file> -n <namespace>
```

### 업그레이드

```bash
helm upgrade <release-name> ./charts/app -f <values-file> -n <namespace>
```

### 삭제

```bash
helm uninstall <release-name> -n <namespace>
```

### Dry-run (테스트)

```bash
helm install <release-name> ./charts/app -f <values-file> -n <namespace> --dry-run --debug
```

### 템플릿 렌더링

```bash
helm template <release-name> ./charts/app -f <values-file>
```

### 값 확인

```bash
helm get values <release-name> -n <namespace>
```

## ArgoCD 사용

ArgoCD Application 예시:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mall-v4-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/AcmeCorp/devops-configs
    targetRevision: main
    path: charts/app
    helm:
      valueFiles:
        - ../../values/apps/mall/v4/api/dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: mall-v4
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

```

## Values 파일 구조 권장사항

프로젝트에서는 다음과 같은 구조를 권장합니다:

```
values/apps/
├── mall/
│   ├── v3/
│   │   ├── api/
│   │   │   ├── dev.yaml
│   │   │   └── prd.yaml
│   │   └── worker/
│   │       ├── dev.yaml
│   │       └── prd.yaml
│   └── v4/
│       ├── api/
│       │   ├── dev.yaml
│       │   └── prd.yaml
│       └── consumer/
│           ├── dev.yaml
│           └── prd.yaml
└── venue/
    ├── beacon-api/
    │   ├── dev.yaml
    │   └── prd.yaml
    └── user-api/
        ├── dev.yaml
        └── prd.yaml
```

## 마이그레이션 가이드

### 기존 차트에서 마이그레이션

#### Mall v3 차트에서

**Before:**
```yaml
# mall/v3/Chart.yaml 사용
```

**After:**
```yaml
# charts/app 사용
fullnameOverride: mall-v3-api

datadog:
  enabled: true
  version: v3

# datadog.tags.env → global.env로 변경
# datadog.tags.version → datadog.version으로 변경
```

#### Mall v4 차트에서

**Before:**
```yaml
# mall/v4/Chart.yaml 사용
env: dev
```

**After:**
```yaml
# charts/app 사용
global:
  env: dev

# env → global.env로 변경
```

#### Venue 차트에서

**Before:**
```yaml
# venue/Chart.yaml 사용
app:
  name: beacon-api
  replicas: 1
  image:
    repository: micro-beacon-service-dev
  probe:
    path: /
    port: 8879
```

**After:**
```yaml
# charts/app 사용
fullnameOverride: beacon-api
replicaCount: 1

image:
  repository: micro-beacon-service-dev

service:
  port: 8879

livenessProbe:
  httpGet:
    path: /
    port: http

readinessProbe:
  httpGet:
    path: /
    port: http
```

## Troubleshooting

### Service Account가 이미 존재하는 경우

Chart는 자동으로 기존 Service Account를 확인하고 이미 존재하면 생성하지 않습니다.

```yaml
serviceAccount:
  create: true
  name: existing-sa  # 이미 존재하는 SA 사용
```

### Namespace가 이미 존재하는 경우

```yaml
namespace:
  create: false  # 이미 존재하는 네임스페이스 사용
  name: existing-namespace
```

### 이미지를 찾을 수 없는 경우

ECR 로그인 확인:
```bash
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin 111111111111.dkr.ecr.ap-northeast-2.amazonaws.com
```

이미지 경로 확인:
```bash
# 전체 이미지 경로 확인
helm template my-app ./charts/app -f values.yaml | grep "image:"
```

## 기여하기

차트 개선이나 버그 수정은 다음 절차를 따라주세요:

1. 기능 브랜치 생성
2. 변경사항 커밋
3. Pull Request 생성
4. 리뷰 후 머지

## 라이선스

Copyright © 2024 AcmeCorp
