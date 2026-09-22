# Datadog → Grafana OSS 마이그레이션

**대상 클러스터**: acme-dev, acme-prd (orbit 제외)
**전환 방식**: dev-first, 단계적 전환 (~4개월)

---

## 스택 구성 (최종 목표)

| 역할 | 도구 | dev | prd |
|------|------|-----|-----|
| 메트릭 수집 | kube-prometheus-stack (Prometheus) | 완료 | 미완 |
| 로그 수집 | Fluent Bit → Loki | 완료 | 미완 |
| 시각화 | Grafana | 운영 중 | 운영 중 |
| 알림 | Alertmanager → Slack | 미완 | 미완 |
| AWS 메트릭 | YACE | 미완 | 미완 |
| AWS 로그 | Vector | 미완 | 미완 |
| 트레이싱 | Tempo | 미완 | 미완 |
| 프로파일링 | Pyroscope | 미완 | 미완 |

---

## 관련 파일

```
argocd/dev/infra/monitoring/
  monitoring.yaml              # Grafana + Loki + Fluent Bit
  kube-prometheus-stack.yaml

values/infra/monitoring/
  kube-prometheus-stack/dev.yaml
  fluent-bit/dev.yaml
  grafana/dev.yaml
  loki/dev.yaml
```

---

## Phase 1 — Dev 완료 (prd 진행 전 필수)

### 완료된 작업

**kube-prometheus-stack** (Prometheus + Alertmanager + node-exporter + kube-state-metrics)
- 포트 충돌 해결: Kubecost node-exporter(9100) → kube-prom-stack(9101)
- ArgoCD app: `argocd/dev/infra/monitoring/kube-prometheus-stack.yaml`
- Values: `values/infra/monitoring/kube-prometheus-stack/dev.yaml`

**Fluent Bit** (Alloy 대체 로그 수집기)
- `Exclude_Path`로 시스템 네임스페이스를 소스 레벨에서 차단
- ArgoCD app: `argocd/dev/infra/monitoring/monitoring.yaml` (alloy → fluent-bit 교체)
- Values: `values/infra/monitoring/fluent-bit/dev.yaml`
- 라벨 구조 변경 — Alloy와 다름:

  | Alloy | Fluent Bit |
  |-------|------------|
  | `namespace` | `kubernetes_namespace_name` |
  | `pod` | `kubernetes_pod_name` |
  | `container` | `kubernetes_container_name` |

**Grafana datasource 업데이트**
- Prometheus: `http://kube-prometheus-stack-prometheus:9090`
- Alertmanager: `http://kube-prometheus-stack-alertmanager:9093`

**Datadog dev 비활성화** — ArgoCD app 주석 처리 완료

**Traefik authentik-oidc-backchannel IngressRoute 제거** — dev에 Authentik 미배포

---

### 남은 작업

#### Slack 알림 설정

Alertmanager 현재 null receiver. 아래 중 하나로 설정한다.

```yaml
# 방법 A: Alertmanager config (values에서 직접)
alertmanager:
  config:
    global:
      slack_api_url: '<webhook-url>'
    route:
      receiver: 'slack'
    receivers:
      - name: 'slack'
        slack_configs:
          - channel: '#alert-dev'
            send_resolved: true

# 방법 B: AlertmanagerConfig CRD (네임스페이스 분리 시 권장)
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
```

결정 필요: 알림 채널명, Bot Token 또는 Webhook URL 방식 선택.

#### Grafana 대시보드 검증

- [ ] 메트릭 대시보드: Node/Pod CPU·Memory 정상 표시
- [ ] 로그 대시보드: Loki 쿼리 정상 동작
- [ ] 기존 Alloy 기반 쿼리에서 라벨명 일괄 업데이트 (`namespace` → `kubernetes_namespace_name` 등)

#### Datadog API key rotation (보안)

git history에 평문 노출된 키 revoke 필요.

1. Datadog UI → Organization Settings → API Keys → 기존 키 Revoke
2. 새 키 생성
3. AWS Secrets Manager `eks/acme-main-dev` → `DATADOG_API_KEY` 값 교체

---

## Phase 2 — Prd 배포 (dev Phase 1 완료 후)

### kube-prometheus-stack prd 배포

Values 파일 신규 작성: `values/infra/monitoring/kube-prometheus-stack/prd.yaml`

dev 대비 변경 포인트:
- 리소스 증가 (노드 ~20개 대응)
- retention 30d
- 스토리지 100Gi 이상
- Alertmanager 2 replicas

ArgoCD app 생성: `argocd/prd/infra/monitoring/kube-prometheus-stack.yaml`

### Fluent Bit prd 배포

Values 파일 신규 작성: `values/infra/monitoring/fluent-bit/prd.yaml`

dev 대비 변경 포인트:
- 리소스 증가 (노드 ~20개 대응)
- prd 네임스페이스 필터 적용
- Loki prd endpoint 연결

`argocd/prd/infra/monitoring/monitoring.yaml`에 fluent-bit source 추가.

### Grafana prd datasource 연결

`values/infra/monitoring/grafana/prd.yaml`에 Prometheus·Alertmanager endpoint 업데이트.

### Datadog Infra Pro 비활성화

prd 메트릭·로그 수집 확인 후 Datadog 플랜 다운그레이드. 비용 절감 목표: Infra Pro 제거.

---

## Phase 3 — AWS 로그/메트릭 연동 (Month 2)

### Vector: S3 로그 → Loki

S3에 저장된 로그를 Vector가 읽어 Loki로 전송.

대상:
- ALB Access Log
- WAF Log
- (선택) CloudFront, VPC Flow, RDS Slow Query

### YACE: CloudWatch 메트릭 → Prometheus

AWS 관리형 서비스 메트릭 수집.

대상: RDS, ElastiCache, SQS, ALB 등

---

## Phase 4 — APM / Profiling 인프라 (Month 3)

**Tempo** (분산 트레이싱)
- dev 먼저 배포
- Grafana datasource 연결

**Pyroscope** (지속 프로파일링)
- dev 먼저 배포
- Grafana datasource 연결

---

## Phase 5 — APM 마이그레이션 (Month 4)

**OTel SDK 연동 순서**: mall-v4 (Java) → venue (Django REST)

```
Java: opentelemetry-javaagent.jar
Python: opentelemetry-sdk (venue)
```

- Datadog APM → OpenTelemetry SDK 교체
- Tempo endpoint 설정

> Python GraphQL은 Datadog APM 미사용 → 마이그레이션 대상 아님
