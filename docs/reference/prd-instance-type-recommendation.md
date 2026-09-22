# PRD 환경 Karpenter 인스턴스 타입 권장안

> 작성일: 2026-01-23
> 대상: acme-main-v2-prd 클러스터

## 1. 요약

| NodePool | 인스턴스 | vCPU | Memory | Capacity | 월 비용 |
|----------|----------|------|--------|----------|---------|
| **Base** | r7i.xlarge | 4 | 32 GiB | On-Demand | $392~588 |
| **Airflow** | c6i.2xlarge | 8 | 16 GiB | On-Demand | ~$248 |
| **Mall v4 Batch** | r7g.large | 2 | 16 GiB | Spot | $23~46 |
| **합계** | | | | | **$695~914** |

---

## 2. 리소스 요구량 분석

### 2.1 Base NodePool 워크로드 (Airflow 제외)

#### Infrastructure 서비스

| 서비스 | Replicas | CPU Requests | Memory Requests |
|--------|----------|--------------|-----------------|
| Traefik | 3~10 (HPA) | 200m/pod | 256Mi/pod |
| External DNS | 1 | 15m | 50Mi |
| AWS LB Controller | 2 | 30m | 100Mi |
| Grafana | 1 | 250m | 512Mi |
| Prometheus | 1 | 500m | 1000Mi |
| Loki | 1 | 100m | 1000Mi |
| Metrics Server | 1 | 15m | 35Mi |
| Kafka UI | 1 | 100m | 256Mi |

#### Venue 서비스

| 서비스 | Replicas | CPU Requests | Memory Requests |
|--------|----------|--------------|-----------------|
| studio-admin-django | 1 | 50m | 1000Mi |
| studio-admin-acme | 1 | 100m | 500Mi |
| user-api | 2 | 40m | 1000Mi |
| beacon-api | 2 | 40m | 1000Mi |
| studio-user-api | 2 | 100m | 2000Mi |
| ins-api | 1 | 100m | 1000Mi |
| play-api | 3 | 240m | 6000Mi |
| member-api | 2 | 40m | 1000Mi |
| 기타 | - | ~100m | ~2000Mi |

#### Mall v3 서비스

| 서비스 | Replicas | CPU Requests | Memory Requests | HPA |
|--------|----------|--------------|-----------------|-----|
| api | 4 | 2400m | 8000Mi | 4~8 |
| worker | 1 | 1000m | 1500Mi | - |
| excel-worker | 1 | 100m | 500Mi | - |
| beat | 1 | 3m | 250Mi | - |

#### Mall v4 서비스 (Batch 제외)

| 서비스 | Replicas | CPU Requests | Memory Requests | HPA |
|--------|----------|--------------|-----------------|-----|
| api | 2 | 1000m | 3000Mi | 2~4 |
| api-seller | 2 | 600m | 2000Mi | - |
| consumer | 1 | 300m | 1000Mi | - |
| api-admin | 1 | 300m | 1500Mi | - |

#### 총합

| 상태 | CPU | Memory |
|------|-----|--------|
| 최소 (현재 replicas) | 8.79 vCPU | 42.05 GiB |
| 피크 (HPA 최대) | 13.59 vCPU | 49.85 GiB |
| **20% 여유 적용** | **16.3 vCPU** | **59.8 GiB** |

### 2.2 Airflow NodePool 워크로드

| 컴포넌트 | Replicas | CPU Requests | Memory Requests |
|----------|----------|--------------|-----------------|
| Scheduler | 2 | 600m | 1600Mi |
| Triggerer | 1 | 40m | 400Mi |
| Webserver | 1 | 2m | 1600Mi |
| **합계** | | **642m** | **3.6 GiB** |

> KubernetesExecutor 사용 시 Worker Pod가 동일 노드에서 실행되므로 여유 공간 필요

### 2.3 Mall v4 Batch 워크로드

| 항목 | 값 |
|------|-----|
| 총 CronJob 수 | ~40개 |
| 각 Job 리소스 | CPU 100m, Memory 950Mi |
| 피크 동시 실행 (0분, 30분) | 최대 17개 |
| **피크 리소스** | **1.7 vCPU, 16.15 GiB** |

**스케줄별 분포:**
- `*/5 분마다`: 6개 (sms, kafka, email, push, cache, qna)
- `*/15 분마다`: 4개 (check-email, payment-token, push-vendor, audit)
- `0,30 분마다`: 5개 (쿠폰 관련, product-option)
- `매시간`: 2개 (search-index, sales-quantity)

---

## 3. NodePool 상세 설계

### 3.1 Base NodePool

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: base
spec:
  template:
    spec:
      requirements:
        - key: node.kubernetes.io/instance-type
          operator: In
          values:
            - r7i.xlarge   # 4 vCPU, 32 GiB (주력)
            - r7i.2xlarge  # 8 vCPU, 64 GiB (피크 대비)
        - key: karpenter.sh/capacity-type
          operator: In
          values:
            - on-demand
        - key: kubernetes.io/arch
          operator: In
          values:
            - amd64
  limits:
    cpu: 20
```

**선택 이유:**
- **r7i (메모리 최적화)**: CPU:Memory 비율이 1:4.8로 메모리 집약적
- **On-Demand**: 서비스 안정성 우선
- **CPU Limit 20**: 기본 2대, 피크 시 3대까지 자동 확장

### 3.2 Airflow NodePool

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: airflow
spec:
  template:
    spec:
      requirements:
        - key: node.kubernetes.io/instance-type
          operator: In
          values:
            - c6i.2xlarge  # 8 vCPU, 16 GiB
        - key: karpenter.sh/capacity-type
          operator: In
          values:
            - on-demand
      taints:
        - key: node-group-type
          value: airflow
          effect: NoSchedule
  limits:
    cpu: 8
```

**선택 이유:**
- **격리**: DAG 실행이 다른 서비스에 영향 주면 안됨
- **c6i (범용)**: CPU/Memory 균형을 유지하면서 메모리 대비 비용 효율 개선
- **충분한 여유**: KubernetesExecutor Worker Pod 스케줄링 공간

### 3.3 Mall v4 Batch NodePool

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: mall-v4-batch
spec:
  template:
    spec:
      requirements:
        - key: node.kubernetes.io/instance-type
          operator: In
          values:
            - r7g.large   # 2 vCPU, 16 GiB (주력)
            - r7g.xlarge  # 4 vCPU, 32 GiB (피크 대비)
        - key: karpenter.sh/capacity-type
          operator: In
          values:
            - spot
        - key: kubernetes.io/arch
          operator: In
          values:
            - arm64
      taints:
        - key: node-group-type
          value: mall-v4-batch
          effect: NoSchedule
  limits:
    cpu: 4
```

**선택 이유:**
- **r7g (Graviton)**: ARM 아키텍처로 20% 비용 절감
- **Spot**: 배치 작업은 중단 시 재실행 가능 → 60-70% 추가 절감
- **메모리 최적화**: CPU:Memory = 1:9.5

---

## 4. 인스턴스 타입 선택 기준

```
워크로드 분석
    │
    ├─ CPU:Memory 비율 확인
    │   ├─ 1:4 이상 → r 시리즈 (메모리 최적화)
    │   └─ 1:4 미만 → m 시리즈 (범용)
    │
    ├─ 중단 허용 여부
    │   ├─ 허용 (배치) → Spot
    │   └─ 불허 (서비스) → On-Demand
    │
    └─ 이미지 호환성
        ├─ ARM 가능 → Graviton (g 시리즈)
        └─ x86 필수 → Intel (i 시리즈)
```

---

## 5. 비용 분석

### 인스턴스 타입별 비용 (ap-northeast-2)

| 인스턴스 | vCPU | Memory | On-Demand/h | Spot/h (~70%) | 월 비용 (On-Demand) |
|----------|------|--------|-------------|---------------|---------------------|
| r7i.xlarge | 4 | 32 GiB | $0.2688 | $0.081 | ~$196 |
| r7i.2xlarge | 8 | 64 GiB | $0.5376 | $0.161 | ~$392 |
| c6i.2xlarge | 8 | 16 GiB | ~$0.34 | ~$0.10 | ~$248 |
| r7g.large | 2 | 16 GiB | $0.107 | $0.032 | ~$78 |
| r7g.xlarge | 4 | 32 GiB | $0.214 | $0.064 | ~$156 |

### 예상 월 비용

| 시나리오 | Base | Airflow | Batch | 합계 |
|----------|------|---------|-------|------|
| 최소 (평상시) | $392 (2대) | ~$248 | $23 | **~$663** |
| 피크 (HPA 최대) | $588 (3대) | ~$248 | $46 | **~$882** |

---

## 6. 적용 방법

### 6.1 Karpenter NodePool 매니페스트 위치

```
manifests/karpenter/prd/
├── base.yaml           # Base NodePool
├── airflow.yaml        # Airflow 전용
└── mall-v4-batch.yaml  # Batch 전용
```

### 6.2 워크로드에 tolerations 추가

**Airflow:**
```yaml
tolerations:
  - key: node-group-type
    operator: Equal
    value: airflow
    effect: NoSchedule
nodeSelector:
  node-group-type: airflow
```

**Mall v4 Batch:**
```yaml
tolerations:
  - key: node-group-type
    operator: Equal
    value: mall-v4-batch
    effect: NoSchedule
nodeSelector:
  node-group-type: mall-v4-batch
```

---

## 7. 모니터링 및 최적화

### 권장 모니터링 지표

- `karpenter_nodes_total_pod_requests` - 노드별 리소스 요청량
- `karpenter_nodes_total_daemon_requests` - DaemonSet 리소스 사용량
- `karpenter_provisioner_limit` - NodePool CPU/Memory 제한
- `karpenter_deprovisioning_actions_performed_total` - 노드 축소 횟수

### 최적화 포인트

1. **VPA 도입 검토**: resources.requests 자동 조정으로 리소스 최적화
2. **HPA 튜닝**: Mall v3 API의 targetCPUUtilization 150% → 80% 조정 권장
3. **Spot Interruption Handler**: Batch NodePool에 필수 설정

---

## 변경 이력

| 날짜 | 변경 내용 | 작성자 |
|------|-----------|--------|
| 2026-01-23 | 최초 작성 | - |
