# 사무실 IP 변경 런북

회사 고정 IP가 바뀔 때(이사 등) **반드시 수정해야 하는 모든 위치**와 절차를 정리한다.

> 현재 회사 IP: `203.0.113.10/32` (기존) + `203.0.113.20/32` (신규 회선) — 2026-06-17 기준 **둘 다 허용 중**. 회선 정리되면 안 쓰는 쪽 제거.

## IP가 박혀 있는 6곳

| # | 파일 | 변수/필드 | 성격 | 잠금 위험 |
|---|------|-----------|------|-----------|
| 1 | `manifests/traefik/prd/middlewares.yaml` | `company-ip-allowlist` → `sourceRange` | 웹 UI 접근(prd) | 🟡 낮음 (git push → ArgoCD 자동 복구) |
| 2 | `manifests/traefik/dev/middlewares.yaml` | `company-ip-allowlist` → `sourceRange` | 웹 UI 접근(dev) | 🟡 낮음 |
| 3 | `stacks/acme/iam/authentik-aws-oidc/prd/terraform.tfvars` | `allowed_source_ips` | **AWS CLI 로그인(prd)** | 🔴 높음 |
| 4 | `stacks/acme/iam/authentik-aws-oidc/dev/terraform.tfvars` | `allowed_source_ips` | **AWS CLI 로그인(dev)** | 🔴 높음 |
| 5 | `stacks/acme/security/cloudtrail-alerts/prd/terraform.tfvars` | `allowed_ips` | 알림용(차단 아님) | ⚪ 없음 (오탐만) |
| 6 | `stacks/acme/security/cloudtrail-alerts/dev/terraform.tfvars` | `allowed_ips` | 알림용(차단 아님) | ⚪ 없음 |

## 두 가지 제한 층 이해

- **① Traefik `company-ip-allowlist`** (1·2번): ArgoCD/Grafana/Kafka UI/Airflow 등 **웹 UI**를 IP로 제한. 막혀도 git push하면 ArgoCD가 git에서 당겨 자동 동기화하므로 UI 없이 복구 가능.
- **② IAM `aws:SourceIp`** (3·4번): `aws-oidc login`(= AWS CLI/kubectl/terraform 전부)을 IP로 제한. **막히면 AWS 직접 접근 불가.** 단, tfvars 고쳐 git push하면 GitHub Actions(GitHub IP)가 terraform apply 하므로 복구는 됨.
- **CloudTrail `allowed_ips`** (5·6번): 차단이 아니라 "비회사 IP 접근 플래그"용. 틀린 IP면 오탐 알림만 발생.

## 절차

### A. 이사 등으로 IP가 곧 바뀔 때 (임시 개방)

1. Traefik (1·2번): `sourceRange`에 `- "0.0.0.0/0"` 임시 추가.
2. IAM (3·4번): `allowed_source_ips = []` (빈 리스트 → IP 조건 제거, SSO 인증은 유지).
3. (선택) CloudTrail (5·6번): 오탐 줄이려면 `allowed_ips = []` 또는 그대로 둠.
4. PR → 머지. Terraform은 CI/CD가 apply, Traefik은 ArgoCD가 sync.

> ⚠️ **이 작업은 IP가 아직 살아있을 때(이사 전) 미리 해두면 잠금 위험이 0.**

### B. 새 고정 IP가 확정됐을 때 (복원)

1. 1·2번: `0.0.0.0/0` 라인 삭제 + 회사 IP를 `<new-ip>/32`로 교체.
2. 3·4번: `allowed_source_ips = ["<new-ip>/32"]`로 복원.
3. 5·6번: `allowed_ips = ["<new-ip>/32"]`로 교체.
4. 이 문서 상단의 "현재 회사 IP"도 갱신.
5. PR → 머지 → 검증.

### 검증

- AWS CLI: 새 IP(또는 개방 상태)에서 `aws-oidc login prd && aws sts get-caller-identity` 성공 확인.
- 웹 UI: `argocd.acme.example` 등 접근 확인.
- ArgoCD: `db-proxy`/`traefik-routes` 등 관련 app `Synced + Healthy`.

## 빠른 grep (변경 누락 방지)

```bash
grep -rn "203.0.113.10" manifests stacks
```
위 명령 결과가 비어 있어야(=구 IP 잔존 없음) 복원 완료.
