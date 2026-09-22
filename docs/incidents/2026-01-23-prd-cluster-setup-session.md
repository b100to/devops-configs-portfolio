# PRD 클러스터 구성 세션 요약 (2026-01-23)

## 개요

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-01-23 |
| 작업 범위 | PRD 클러스터 Traefik 헬스체크 수정 + Karpenter NodePool 설계 |
| 상태 | 구성 단계 (라이브 전) |

## 1. Traefik 헬스체크 포트 수정

### 문제
- ALB healthcheck-port: `9000`
- Traefik ping.entryPoint: `web` (port 8000)
- 포트 불일치로 헬스체크 실패 가능성

### 해결
```yaml
# values/infra/traefik/prd.yaml
ping:
  enabled: true
  entryPoint: traefik  # web(8000) → traefik(9000)으로 변경
```

## 2. Karpenter NodePool 설계

### 리소스 분석 결과

| 워크로드 | CPU (Peak) | Memory (Peak) |
|----------|------------|---------------|
| Infrastructure | 2.48 vCPU | 3.85 GiB |
| Venue | 1.65 vCPU | 2.60 GiB |
| Mall v3 | 0.45 vCPU | 1.28 GiB |
| Mall v4 | 9.00 vCPU | 23.00 GiB |
| **합계** | **13.58 vCPU** | **30.73 GiB** |

- CPU:Memory 비율 = 1:2.3 → 메모리 집약적
- **r7i (메모리 최적화) 선택**

### NodePool 구성

| NodePool | 용도 | 인스턴스 타입 | Capacity | CPU Limit |
|----------|------|--------------|----------|-----------|
| Base | 일반 워크로드 | r7i.xlarge, r7i.2xlarge | Spot | 20 |
| Airflow | Airflow 전용 | m6i.2xlarge | Spot | 8 |
| Batch | CronJob 전용 | r7g.large/xlarge, r7i.large/xlarge | Spot | 4 |

### 수정된 파일

#### config.tm.hcl
```hcl
globals {
  environment   = "prd"
  account_id    = "222222222222"
  instance_type = "r7i.xlarge"  # 메모리 최적화 (4 vCPU, 32GB)
  cpu_limit     = "20"          # 5 nodes x 4 vCPU = 20 cores
}
```

#### nodepool.yaml.tmpl
```yaml
requirements:
  - key: node.kubernetes.io/instance-type
    operator: In
    values:
      - "${instance_type}"  # r7i.xlarge (4 vCPU, 32 GiB)
      - "r7i.2xlarge"       # 8 vCPU, 64 GiB (피크 대비)
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot"]  # 구성 단계 비용 절감
```

#### batch.yaml (mall-v4-batch.yaml에서 이름 변경)
- NodePool 이름: `mall-v4-batch` → `batch`
- ARM + Intel 모두 지원: r7g.large, r7g.xlarge, r7i.large, r7i.xlarge
- Spot 인스턴스 사용

#### airflow.yaml
- Capacity: `on-demand` → `spot` (구성 단계 비용 절감)

## 3. 비용 최적화 전략

### 현재 설정 (구성 단계)
- **전체 NodePool Spot 사용** → 약 70% 비용 절감

### Datadog 비용 최적화 (노드 수 최소화)
Datadog per-host 과금으로 인해 노드 수를 최소화해야 함.

**전략**: NodePool weight를 활용한 큰 인스턴스 우선 스케줄링

| NodePool | 인스턴스 타입 | Weight | CPU Limit | 역할 |
|----------|--------------|--------|-----------|------|
| base-2xlarge | r7i.2xlarge | 100 | 16 | 우선 스케줄링 (2대로 모든 워크로드 수용) |
| base | r7i.xlarge | 10 | 8 | 폴백용 (2xlarge Spot 불가 시) |

**관련 파일**:
- `manifests/karpenter/prd/base-2xlarge.yaml` (신규)
- `stacks/acme/manifests/karpenter/prd/nodepool.yaml.tmpl` (weight: 10으로 변경)

### 라이브 전환 시 변경 예정
| NodePool | 변경 |
|----------|------|
| Base | Spot → On-Demand |
| Airflow | Spot → On-Demand |
| Batch | Spot 유지 |

## 4. 문서화

- 상세 인스턴스 타입 추천 문서: [docs/prd-instance-type-recommendation.md](../reference/prd-instance-type-recommendation.md)

## 5. 라이브 전 주의사항

### 배치성 워크로드 (replicaCount: 0 유지)
다음 워크로드들은 **라이브 전까지 replicaCount: 0** 유지 필요:

| 서비스 | 파일 | 이유 |
|--------|------|------|
| mall-v3-beat | `values/apps/mall/v3/beat/prd.yaml` | Celery Beat 스케줄러 - 라이브 전 실행 불필요 |

### External-DNS 수정

**문제**: Route53 레코드 생성 실패
- 원인: `domainFilters`가 `v2.acme.example` 등 서브도메인으로 설정됨
- Route53 hosted zone은 `acme.example` (부모 도메인)

**해결**: `values/infra/external-dns/prd.yaml`
```yaml
domainFilters:
  - acme.example
  - acme-corp.example
  - acmemall.example
```

### Helm Chart 수정

**문제**: mall-reco-api 배포 시 YAML 파싱 에러
```
block sequence entries are not allowed in this context at line 101
```

**원인**: `charts/app/templates/_helpers.tpl`의 whitespace 처리 오류

**수정 1**: `app.awsEnv` - credentials nil 체크 추가
```go-template
{{- if and .Values.aws.credentials .Values.aws.credentials.fromSecret }}
```

**수정 2**: `app.env` - 줄바꿈 보존
```go-template
{{- if .Values.env }}
{{ toYaml .Values.env }}  # {{- 대신 {{ 사용하여 앞줄 줄바꿈 보존
{{- end }}
```

## 다음 단계

### 완료
- [x] Karpenter 설정 Terramate/ArgoCD로 배포
- [x] Karpenter NodePool weight 기반 비용 최적화 (base-2xlarge)
- [x] External-DNS domainFilters 수정
- [x] Helm Chart _helpers.tpl whitespace 수정

### 미완료 (라이브 전 필수)
- [ ] External-DNS 변경사항 ArgoCD sync
- [ ] 라이브 전환 전 On-Demand 전환 계획 수립
- [ ] 모니터링 대시보드 구성
- [ ] mall-v3-beat replicaCount: 1로 변경 (라이브 시)

## 6. 트러블슈팅

### EC2NodeClass Terminating 상태 고착

**상황**: base EC2NodeClass가 Terminating 상태에서 삭제되지 않음

**원인**: Karpenter controller가 실행 중이지 않은 상태에서 finalizer가 남아있음

**해결**:
1. Karpenter helm 재설치
   ```bash
   cd modules/manifests/karpenter
   AWS_PROFILE=prd terramate run --enable-sharing -- terraform apply -auto-approve
   ```
2. Finalizer 수동 제거 (필요시)
   ```bash
   kubectl patch ec2nodeclass base -p '{"metadata":{"finalizers":null}}' --type=merge
   ```

## 관련 인시던트

- [2026-01-22 ALB SG 인시던트](./2026-01-22-alb-sg-incident.md) - AWS LB Controller의 보안 그룹 자동 관리 문제
