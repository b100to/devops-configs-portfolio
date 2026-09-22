# Batch Helm Chart

CronJob 워크로드를 위한 통합 Helm 차트입니다.

## 주요 특징

- ✅ **여러 CronJob 관리**: 하나의 차트로 여러 CronJob 정의
- ✅ **공통 설정**: `commonValues`로 모든 Job에 공통 설정 적용
- ✅ **개별 설정**: 각 Job별로 스케줄, 명령어 등 커스터마이징
- ✅ **Namespace 관리**: 네임스페이스 자동 생성 지원
- ✅ **Datadog 통합**: Datadog APM, 로그 자동 연동
- ✅ **AWS 통합**: AWS 자격 증명, 리전 설정 지원
- ✅ **유연한 설정**: 리소스, 스케줄링, 환경 변수 등 커스터마이징

## Chart 구조

```
batch/
├── Chart.yaml
├── values.yaml                 # 기본 values
├── templates/
│   ├── _helpers.tpl           # Helper 함수들
│   ├── namespace.yaml         # Namespace 생성
│   └── cronjob.yaml           # CronJob 생성
└── examples/
    └── mall-v4-batch-dev.yaml # 실제 사용 예시
```

## 빠른 시작

### 기본 설치

```bash
helm install my-batch ./charts/batch \
  -f ./charts/batch/examples/mall-v4-batch-dev.yaml
```

## Values 구조

### commonValues (모든 CronJob에 공통 적용)

```yaml
commonValues:
  global:
    env: dev
    registry:
      accountId: "111111111111"
      region: "ap-northeast-2"

  fullnameOverride: my-batch
  
  namespace:
    name: my-namespace

  image:
    repository: my-batch-image
    tag: latest

  serviceAccount:
    name: my-sa

  resources:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      memory: 512Mi

  aws:
    enabled: true

  datadog:
    enabled: true
    version: v1
```

### app (각 CronJob별 설정)

```yaml
app:
  job-name-1:
    schedule: "0 2 * * *"
    command:
      - /bin/sh
      - -c
      - echo "Job 1"
  
  job-name-2:
    schedule: "0 * * * *"
    command:
      - /bin/sh
      - -c
      - echo "Job 2"
```

## 설정 가이드

### CronJob 스케줄

```yaml
app:
  my-job:
    schedule: "0 2 * * *"        # 매일 오전 2시
    timeZone: "Asia/Seoul"       # 타임존 설정
    suspend: false               # Job 일시 정지
```

#### 스케줄 예시

```yaml
# 매일 오전 2시
schedule: "0 2 * * *"

# 매시간
schedule: "0 * * * *"

# 매주 월요일 오전 3시
schedule: "0 3 * * 1"

# 매월 1일 오전 0시
schedule: "0 0 1 * *"

# 5분마다
schedule: "*/5 * * * *"
```

### Job 히스토리 및 동시 실행 제어

```yaml
app:
  my-job:
    successfulJobsHistoryLimit: 3   # 성공한 Job 히스토리 개수
    failedJobsHistoryLimit: 3       # 실패한 Job 히스토리 개수
    concurrencyPolicy: Forbid       # 동시 실행 정책
```

#### ConcurrencyPolicy

- `Allow`: 동시 실행 허용
- `Forbid`: 동시 실행 금지 (기본값)
- `Replace`: 기존 Job을 새 Job으로 교체

### Job 실행 제한

```yaml
app:
  my-job:
    backoffLimit: 3                 # 재시도 횟수
    activeDeadlineSeconds: 3600     # 최대 실행 시간 (초)
    ttlSecondsAfterFinished: 86400  # Job 완료 후 삭제까지 시간 (초)
```

### Pod 재시작 정책

```yaml
app:
  my-job:
    restartPolicy: Never  # Never 또는 OnFailure
```

### Command 설정

#### Shell 명령어

```yaml
app:
  my-job:
    command:
      - /bin/sh
      - -c
      - |
        echo "Starting job"
        ./my-script.sh
        echo "Job completed"
```

#### Java 애플리케이션

```yaml
app:
  my-job:
    command:
      - java
      - -jar
      - app.jar
      - --job.name=my-job
      - --spring.profiles.active=dev
```

#### Python 스크립트

```yaml
app:
  my-job:
    command:
      - python
      - -u
      - /app/batch_job.py
    args:
      - --config
      - /etc/config/job.yaml
```

### Istio Sidecar 비활성화

Batch Job은 일반적으로 Istio Sidecar가 필요 없습니다:

```yaml
app:
  my-job:
    disableIstio: true  # sidecar.istio.io/inject: "false" 레이블 추가
```

### Init Containers

```yaml
commonValues:
  initContainers:
    - name: wait-for-db
      image: busybox
      command:
        - sh
        - -c
        - |
          until nc -z postgres 5432; do
            echo "Waiting for DB..."
            sleep 2
          done
```

### Environment Variables

#### 기본 환경 변수

```yaml
commonValues:
  env:
    - name: JOB_ENV
      value: production
    - name: DB_HOST
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: host
```

#### ConfigMap/Secret에서 전체 주입

```yaml
commonValues:
  envFrom:
    - configMapRef:
        name: batch-config
    - secretRef:
        name: batch-secret
```

### Resources

```yaml
commonValues:
  resources:
    requests:
      cpu: 200m
      memory: 1Gi
    limits:
      memory: 2Gi
```

### Scheduling

#### Node Selector

```yaml
commonValues:
  nodeSelector:
    karpenter.sh/nodepool: batch
```

#### Tolerations

```yaml
commonValues:
  tolerations:
    - key: node-group-type
      operator: Equal
      value: batch
      effect: NoSchedule
```

#### Affinity

```yaml
commonValues:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: karpenter.sh/nodepool
            operator: In
            values: ["batch"]
```

## 실전 예시

### 여러 개의 Batch Job

```yaml
commonValues:
  global:
    env: dev
    registry:
      accountId: "111111111111"
      region: "ap-northeast-2"

  fullnameOverride: mall-batch
  namespace:
    name: mall

  image:
    repository: mall-batch
    tag: v1.0.0

  resources:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      memory: 1Gi

  datadog:
    enabled: true
    version: v1

app:
  # 매일 오전 2시 - 주문 데이터 정리
  order-cleanup:
    schedule: "0 2 * * *"
    timeZone: "Asia/Seoul"
    concurrencyPolicy: Forbid
    ttlSecondsAfterFinished: 86400
    disableIstio: true
    command:
      - java
      - -jar
      - app.jar
      - --job.name=order-cleanup

  # 매시간 - 재고 동기화
  inventory-sync:
    schedule: "0 * * * *"
    timeZone: "Asia/Seoul"
    concurrencyPolicy: Replace
    activeDeadlineSeconds: 1800
    disableIstio: true
    command:
      - java
      - -jar
      - app.jar
      - --job.name=inventory-sync

  # 매주 월요일 - 주간 리포트
  weekly-report:
    schedule: "0 3 * * 1"
    timeZone: "Asia/Seoul"
    concurrencyPolicy: Forbid
    backoffLimit: 1
    ttlSecondsAfterFinished: 604800
    disableIstio: true
    command:
      - java
      - -jar
      - app.jar
      - --job.name=weekly-report
```

## Helm 명령어

### 설치

```bash
helm install <release-name> ./charts/batch -f <values-file> -n <namespace>
```

### 업그레이드

```bash
helm upgrade <release-name> ./charts/batch -f <values-file> -n <namespace>
```

### 특정 Job 일시 정지

```bash
helm upgrade <release-name> ./charts/batch \
  -f <values-file> \
  --set app.my-job.suspend=true \
  -n <namespace>
```

### 삭제

```bash
helm uninstall <release-name> -n <namespace>
```

### Dry-run

```bash
helm install <release-name> ./charts/batch -f <values-file> -n <namespace> --dry-run --debug
```

## Job 관리

### Job 수동 실행

```bash
# CronJob에서 즉시 Job 생성
kubectl create job --from=cronjob/<cronjob-name> <job-name> -n <namespace>
```

### Job 상태 확인

```bash
# CronJob 목록
kubectl get cronjobs -n <namespace>

# Job 목록
kubectl get jobs -n <namespace>

# Pod 로그 확인
kubectl logs -n <namespace> -l job-name=<job-name>
```

### Job 일시 정지/재개

```bash
# 일시 정지
kubectl patch cronjob <cronjob-name> -n <namespace> -p '{"spec":{"suspend":true}}'

# 재개
kubectl patch cronjob <cronjob-name> -n <namespace> -p '{"spec":{"suspend":false}}'
```

## Troubleshooting

### Job이 실행되지 않음

1. CronJob이 suspend 상태인지 확인
```bash
kubectl get cronjob <cronjob-name> -n <namespace> -o yaml | grep suspend
```

2. 스케줄 확인
```bash
kubectl get cronjob <cronjob-name> -n <namespace> -o yaml | grep schedule
```

### Job이 실패함

1. Pod 로그 확인
```bash
kubectl logs -n <namespace> -l job-name=<job-name>
```

2. Job 상세 정보 확인
```bash
kubectl describe job <job-name> -n <namespace>
```

3. backoffLimit 증가
```yaml
app:
  my-job:
    backoffLimit: 5  # 재시도 횟수 증가
```

### Job이 오래 실행됨

```yaml
app:
  my-job:
    activeDeadlineSeconds: 3600  # 최대 1시간
```

### 오래된 Job이 쌓임

```yaml
app:
  my-job:
    ttlSecondsAfterFinished: 86400  # 24시간 후 자동 삭제
    successfulJobsHistoryLimit: 1
    failedJobsHistoryLimit: 3
```

## 마이그레이션 가이드

### 기존 acmemall-backend-v4-batch에서

**Before:**
```yaml
commonValues:
  env: dev
  image:
    name: 111111111111.dkr.ecr.ap-northeast-2.amazonaws.com/repo
    tag: latest
```

**After:**
```yaml
commonValues:
  global:
    env: dev
    registry:
      accountId: "111111111111"
      region: "ap-northeast-2"
  image:
    repository: repo
    tag: latest
```

## 라이선스

Copyright © 2024 AcmeCorp
