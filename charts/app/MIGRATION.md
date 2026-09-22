# Values Migration Guide

이 가이드는 기존 차트의 values 파일을 새로운 통합 차트로 마이그레이션하는 방법을 설명합니다.

## 목차

1. [Mall v3 마이그레이션](#mall-v3-마이그레이션)
2. [Mall v4 마이그레이션](#mall-v4-마이그레이션)
3. [Venue 마이그레이션](#venue-마이그레이션)
4. [자동 변환 스크립트](#자동-변환-스크립트)

---

## Mall v3 마이그레이션

### Before (기존 mall/v3 차트)

```yaml
fullnameOverride: mall-v3-api
replicaCount: 2

image:
  name: 111111111111.dkr.ecr.ap-northeast-2.amazonaws.com/acmemall-backend-v3/dev/api
  tag: latest
  pullPolicy: IfNotPresent

annotations:
  deployment.example.com/version: "1.0"

command:
  - python
  - manage.py
  - runserver

service:
  type: ClusterIP
  port: 8000

livenessProbe:
  enabled: true
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
  successThreshold: 1

readinessProbe:
  enabled: true
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
  successThreshold: 1

resources:
  limits:
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 1Gi

autoscaling:
  enabled: false

env:
  - name: DJANGO_SETTINGS_MODULE
    value: config.settings.dev
  - name: DATABASE_HOST
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: host

datadog:
  tags:
    env: dev
    version: v3

nodeSelector:
  karpenter.sh/nodepool: mall-v3

tolerations:
  - key: node-group-type
    operator: Equal
    value: mall-v3
    effect: NoSchedule
```

### After (새로운 app 차트)

```yaml
# Global 설정 추가
global:
  env: dev
  registry:
    accountId: "111111111111"
    region: "ap-northeast-2"

# 기본 설정 유지
fullnameOverride: mall-v3-api

# Namespace 설정 추가 (선택사항)
namespace:
  name: mall-v3

replicaCount: 2

# Image 설정 변경
image:
  # registry 정보는 global로 이동
  repository: acmemall-backend-v3/dev/api
  tag: latest
  pullPolicy: IfNotPresent

# Service Account 추가
serviceAccount:
  create: true
  name: default

# Deployment annotations 유지
annotations:
  deployment.example.com/version: "1.0"

# Command 유지
command:
  - python
  - manage.py
  - runserver

# Service 설정 개선
service:
  enabled: true  # 명시적 활성화
  type: ClusterIP
  port: 8000
  targetPort: 8000  # 명시적 지정

# Health Check - httpGet 추가
livenessProbe:
  enabled: true
  httpGet:
    path: /ht/
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
  successThreshold: 1

readinessProbe:
  enabled: true
  httpGet:
    path: /ht/
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
  successThreshold: 1

# Resources 유지
resources:
  limits:
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 1Gi

# Autoscaling 유지
autoscaling:
  enabled: false

# Env 유지
env:
  - name: DJANGO_SETTINGS_MODULE
    value: config.settings.dev
  - name: DATABASE_HOST
    valueFrom:
      secretKeyRef:
        name: db-secret
        key: host

# Datadog 설정 변경
datadog:
  enabled: true
  version: v3  # tags.version → version
  logsInjection: "true"
  traceSampleRate: "0.1"

# Labels 추가 (기존 node-group-type)
labels:
  node-group-type: mall-v3

# Scheduling 유지
nodeSelector:
  karpenter.sh/nodepool: mall-v3

tolerations:
  - key: node-group-type
    operator: Equal
    value: mall-v3
    effect: NoSchedule

# Topology Spread 추가
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: mall-v3-api
```

### 변경 사항 요약

1. ✅ `global` 섹션 추가
2. ✅ `image.name` → `image.repository` (registry는 global로)
3. ✅ `datadog.tags.env` → `global.env`
4. ✅ `datadog.tags.version` → `datadog.version`
5. ✅ `service.enabled` 명시적 추가
6. ✅ `livenessProbe/readinessProbe`에 `httpGet` 섹션 추가
7. ✅ `serviceAccount` 섹션 추가
8. ✅ `topologySpreadConstraints` 추가

---

## Mall v4 마이그레이션

### Before (기존 mall/v4 차트)

```yaml
env: dev

fullnameOverride: mall-v4-api
replicaCount: 1

image:
  name: 111111111111.dkr.ecr.ap-northeast-2.amazonaws.com/acmemall-backend-v4/dev/api
  pullPolicy: IfNotPresent

podAnnotations:
  admission.datadoghq.com/java-lib.version: "v1.37.1"

service:
  type: ClusterIP
  port: 8080

serviceAccount:
  name: app-mall

resources:
  limits:
    memory: 900Mi
  requests:
    cpu: 50m
    memory: 900Mi

autoscaling:
  enabled: false

livenessProbe:
  enabled: true
  initialDelaySeconds: 5
  periodSeconds: 15
  timeoutSeconds: 1
  failureThreshold: 3
  successThreshold: 1

readinessProbe:
  enabled: true
  initialDelaySeconds: 5
  periodSeconds: 15
  timeoutSeconds: 1
  failureThreshold: 3
  successThreshold: 1

startupProbe:
  enabled: true
  periodSeconds: 10
  failureThreshold: 30
```

### After (새로운 app 차트)

```yaml
# Global 설정 추가
global:
  env: dev  # env → global.env
  registry:
    accountId: "111111111111"
    region: "ap-northeast-2"

fullnameOverride: mall-v4-api

# Namespace 설정 추가
namespace:
  name: mall-v4

replicaCount: 1

# Image 설정 변경
image:
  repository: acmemall-backend-v4/dev/api
  tag: latest  # 명시적 추가
  pullPolicy: IfNotPresent

# Service Account 설정 변경
serviceAccount:
  create: true  # 생성 여부 명시
  name: app-mall
  # annotations:  # IAM Role이 있다면 추가
  #   eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/mall-v4-role

podAnnotations:
  admission.datadoghq.com/java-lib.version: "v1.37.1"

# Service 설정 개선
service:
  enabled: true
  type: ClusterIP
  port: 8080
  targetPort: 8080

resources:
  limits:
    memory: 900Mi
  requests:
    cpu: 50m
    memory: 900Mi

autoscaling:
  enabled: false

# Health Check - httpGet 추가
livenessProbe:
  enabled: true
  httpGet:
    path: /actuator/health/liveness
    port: http
  initialDelaySeconds: 5
  periodSeconds: 15
  timeoutSeconds: 1
  failureThreshold: 3
  successThreshold: 1

readinessProbe:
  enabled: true
  httpGet:
    path: /actuator/health/readiness
    port: http
  initialDelaySeconds: 5
  periodSeconds: 15
  timeoutSeconds: 1
  failureThreshold: 3
  successThreshold: 1

startupProbe:
  enabled: true
  httpGet:
    path: /actuator/health/liveness
    port: http
  periodSeconds: 10
  failureThreshold: 30

# AWS 설정 추가
aws:
  enabled: true
  region: ap-northeast-2
  credentials:
    fromSecret: true
    secretName: aws-account

# Datadog 설정 추가
datadog:
  enabled: true
  version: v4
  logsInjection: "true"
  traceSampleRate: "0.1"

# Topology Spread 추가
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: mall-v4-api
```

### 변경 사항 요약

1. ✅ `env` → `global.env`
2. ✅ `image.name` → `image.repository` + `image.tag`
3. ✅ `serviceAccount.create` 추가
4. ✅ Health Check에 `httpGet` 섹션 추가
5. ✅ `aws` 섹션 추가
6. ✅ `datadog` 섹션 추가
7. ✅ `namespace` 섹션 추가

---

## Venue 마이그레이션

### Before (기존 venue 차트)

```yaml
global:
  env: dev
  registry:
    accountId: "111111111111"

app:
  name: beacon-api
  replicas: 1
  priorityClassName: high-priority
  image:
    repository: micro-beacon-service-dev
  probe:
    path: /
    port: 8879
  resources:
    requests:
      cpu: 15m
      memory: 500Mi
    limits:
      memory: 500Mi
  env:
    - name: DD_TRACING_ENABLED
      value: "false"
    - name: DD_TRACE_ENABLED
      value: "false"
    - name: SPRING_PROFILES_ACTIVE
      value: dev
  labels:
    team: venue
```

### After (새로운 app 차트)

```yaml
# Global 설정 개선
global:
  env: dev
  registry:
    accountId: "111111111111"
    region: "ap-northeast-2"  # 추가

# 기본 설정
fullnameOverride: beacon-api  # app.name → fullnameOverride

# Namespace 설정
namespace:
  name: venue

replicaCount: 1  # app.replicas → replicaCount

priorityClassName: high-priority

# Image 설정
image:
  repository: micro-beacon-service-dev
  tag: latest
  pullPolicy: IfNotPresent

# Service Account 추가
serviceAccount:
  create: true
  name: app-venue

# Service 설정 추가
service:
  enabled: true
  type: ClusterIP
  port: 8879  # app.probe.port → service.port
  targetPort: 8879

# Health Check 설정 변경
livenessProbe:
  enabled: true
  httpGet:
    path: /  # app.probe.path
    port: http  # app.probe.port
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 10
  successThreshold: 1

readinessProbe:
  enabled: true
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 10
  successThreshold: 1

# Resources 설정
resources:  # app.resources → resources
  requests:
    cpu: 15m
    memory: 500Mi
  limits:
    memory: 500Mi

# Autoscaling 추가
autoscaling:
  enabled: false

# Environment Variables
env:  # app.env → env
  - name: DD_TRACING_ENABLED
    value: "false"
  - name: DD_TRACE_ENABLED
    value: "false"
  - name: SPRING_PROFILES_ACTIVE
    value: dev

# Labels 추가
labels:  # app.labels → labels
  team: venue

# AWS 설정
aws:
  enabled: true
  region: ap-northeast-2

# Datadog 설정
datadog:
  enabled: false  # DD_TRACING_ENABLED가 false이므로

# Topology Spread
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: beacon-api
```

### 변경 사항 요약

1. ✅ `app.name` → `fullnameOverride`
2. ✅ `app.replicas` → `replicaCount`
3. ✅ `app.image.repository` → `image.repository`
4. ✅ `app.probe.path` → `livenessProbe.httpGet.path` / `readinessProbe.httpGet.path`
5. ✅ `app.probe.port` → `service.port`
6. ✅ `app.resources` → `resources`
7. ✅ `app.env` → `env`
8. ✅ `app.labels` → `labels`
9. ✅ `serviceAccount` 섹션 추가
10. ✅ `service` 섹션 추가

---

## 자동 변환 스크립트

### Mall v3 변환 스크립트

```bash
#!/bin/bash
# convert-mall-v3.sh

INPUT_FILE=$1
OUTPUT_FILE=$2

if [ -z "$INPUT_FILE" ] || [ -z "$OUTPUT_FILE" ]; then
  echo "Usage: $0 <input-file> <output-file>"
  exit 1
fi

# YQ를 사용한 자동 변환 (yq 설치 필요: brew install yq)
yq eval '
  # Global 섹션 추가
  .global.env = .datadog.tags.env |
  .global.registry.accountId = "111111111111" |
  .global.registry.region = "ap-northeast-2" |
  
  # Image 변환
  .image.repository = (.image.name | split("/") | .[1:] | join("/")) |
  del(.image.name) |
  
  # Datadog 변환
  .datadog.enabled = true |
  .datadog.version = .datadog.tags.version |
  del(.datadog.tags) |
  
  # Service 개선
  .service.enabled = true |
  .service.targetPort = .service.port |
  
  # Probe에 httpGet 추가
  .livenessProbe.httpGet.path = "/ht/" |
  .livenessProbe.httpGet.port = 8000 |
  .readinessProbe.httpGet.path = "/ht/" |
  .readinessProbe.httpGet.port = 8000
' "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Converted $INPUT_FILE to $OUTPUT_FILE"
```

### 사용 예시

```bash
# Mall v3 변환
./convert-mall-v3.sh \
  values/apps/mall/v3/api/dev.yaml \
  values/apps/mall/v3/api/dev-new.yaml

# Mall v4 변환
./convert-mall-v4.sh \
  values/apps/mall/v4/api/dev.yaml \
  values/apps/mall/v4/api/dev-new.yaml

# Venue 변환
./convert-venue.sh \
  values/apps/venue/beacon-api/dev.yaml \
  values/apps/venue/beacon-api/dev-new.yaml
```

---

## 검증

변환 후 다음 명령어로 검증하세요:

```bash
# Lint 검증
helm lint charts/app -f <new-values-file>

# Template 렌더링 테스트
helm template test-app charts/app -f <new-values-file>

# Dry-run 테스트
helm install test-app charts/app \
  -f <new-values-file> \
  -n test-namespace \
  --dry-run --debug
```

---

## FAQ

### Q: 기존 차트와 동시에 사용할 수 있나요?
A: 네, 기존 차트와 새 차트는 별도의 릴리스로 관리되므로 동시 사용 가능합니다.

### Q: 마이그레이션 중 다운타임이 있나요?
A: 새로운 릴리스로 배포하므로 다운타임 없이 전환 가능합니다. Blue-Green 방식으로 진행하세요.

### Q: 모든 values를 변환해야 하나요?
A: 필수 필드만 변환하고 나머지는 기본값을 사용할 수 있습니다.

### Q: 롤백이 가능한가요?
A: 네, `helm rollback` 명령어로 이전 버전으로 롤백할 수 있습니다.

---

## 지원

문제가 발생하면:
1. README.md 참고
2. TESTING.md로 검증
3. GitHub Issues 생성
4. DevOps 팀에 문의
