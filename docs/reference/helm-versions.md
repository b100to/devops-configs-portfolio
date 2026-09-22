# Helm Chart Versions

현재 운영 중인 Helm chart 버전과 관리 정책을 정의한다.

## 현재 버전

| Chart | 버전 | Repository | 환경 |
|-------|------|------------|------|
| `traefik/traefik` | 38.0.0 | `https://traefik.github.io/charts` | dev, prd |
| `eks/aws-load-balancer-controller` | 1.16.0 | `https://aws.github.io/eks-charts` | dev, prd |
| `external-dns/external-dns` | 9.0.3 | `https://charts.bitnami.com/bitnami` | dev, prd |
| `confluentinc/kafka` | 32.4.3 | `https://confluentinc.github.io/cp-helm-charts` | dev |
| `kafka-ui/kafka-ui` | 1.5.3 | `https://provectus.github.io/kafka-ui-charts` | dev |
| `aws-ebs-csi-driver` | 2.53.0 | `https://aws.github.io/eks-charts` | dev, prd |
| `bitnami/redis` | 23.2.2 | `https://charts.bitnami.com/bitnami` | dev |
| `cost-analyzer/kubecost` | 2.8.6 | `https://kubecost.github.io/cost-analyzer` | dev, prd |
| `argo-workflows` | 0.47.4 | `https://argoproj.github.io/argo-helm` | prd |
| `goauthentik.io/authentik` | 2025.10.3 | `https://charts.goauthentik.io` | dev, prd |
| `apache/airflow` | 1.15.0 | `https://airflow.apache.org` | prd |
| `apache/airflow` | 1.21.0 | `https://airflow.apache.org` | prd-green |

버전은 ArgoCD Application의 `targetRevision`으로 고정된다.

---

## 버전 관리 정책

- **고정 버전 사용**: `targetRevision: latest` 금지. 항상 특정 버전을 명시한다.
- **`_defaults.yaml` 동기화**: 버전 업그레이드 시 반드시 `_defaults.yaml`을 함께 갱신한다.
- **환경별 독립 관리**: dev와 prd의 버전을 독립적으로 관리할 수 있다. 단, prd 적용 전 dev에서 먼저 검증한다.

---

## 버전 업그레이드 절차

### 1. 변경사항 확인

```bash
# 현재 chart 변경 사항 확인
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm search repo traefik/traefik --versions | head -5

# changelog 확인 (각 chart GitHub releases 페이지)
```

### 2. _defaults.yaml 갱신

```bash
# 새 버전의 기본값으로 갱신
helm show values traefik/traefik --version 38.1.0 \
  > /path/to/values/infra/traefik/_defaults.yaml
```

`_defaults.yaml`은 환경별 values 파일 작성 시 기준이 된다. 항상 최신 버전의 기본값을 반영해야 제거된 옵션이나 추가된 옵션을 파악할 수 있다.

### 3. ArgoCD Application 버전 변경 (dev 먼저)

```yaml
# argocd/dev/infra/networking/traefik.yaml
sources:
  - repoURL: https://traefik.github.io/charts
    chart: traefik
    targetRevision: 38.1.0    # 버전 변경
```

### 4. git push → ArgoCD 동기화 확인

```bash
git add argocd/dev/ values/infra/traefik/_defaults.yaml
git commit -m "chore(traefik/dev): upgrade chart 38.0.0 → 38.1.0"
git push

# ArgoCD 상태 확인
argocd app get traefik -o json | jq '{sync: .status.sync.status, health: .status.health.status}'
```

### 5. dev 검증 후 prd 적용

dev에서 정상 동작 확인 후 동일하게 prd ArgoCD Application을 수정한다.

---

## _defaults.yaml 관리

`values/infra/{chart}/_defaults.yaml` 은 `helm show values` 결과 원본이다.

- 직접 수정하지 않는다 — 항상 `helm show values`로 재생성
- 환경별 values(`dev.yaml`, `prd.yaml`)에서 기본값과 다른 설정에만 주석으로 이유를 명시한다

```bash
# 예시: external-secrets _defaults.yaml 재생성
helm repo add external-secrets https://charts.external-secrets.io
helm show values external-secrets/external-secrets --version 0.14.0 \
  > values/infra/external-secrets/_defaults.yaml
```

---

## Chart.yaml missing 에러 해결 (로컬 .tgz 참조)

CI 환경에서 Terraform Helm provider가 HTTP repository에서 chart를 다운로드하지 못하는 경우가 있다. 이때는 chart `.tgz`를 git에 커밋하고 로컬 파일을 직접 참조한다.

해당 패턴이 적용된 스택: `argocd`, `external-secrets`, `karpenter`, `ebs-csi-driver`

```hcl
# Terraform Helm provider에서 로컬 .tgz 참조 예시
resource "helm_release" "argocd" {
  name  = "argocd"
  chart = "${path.module}/.helm/argo-cd-7.8.23.tgz"    # 로컬 파일 직접 참조

  # repository = "https://..." 제거
  # version    = "..."          제거
}
```

```bash
# .tgz 다운로드 및 커밋
helm pull argo-cd --repo https://argoproj.github.io/argo-helm --version 7.8.23 \
  -d modules/07_argocd-helm/.helm/

git add modules/07_argocd-helm/.helm/argo-cd-7.8.23.tgz
git commit -m "chore(argocd-helm): bundle chart tgz for CI"
```

ArgoCD를 통해 배포하는 chart (Traefik, AWS-LB-Controller 등)는 이 패턴이 필요 없다. ArgoCD가 직접 repository에서 다운로드하기 때문이다. 이 패턴은 **Terraform Helm provider**를 사용하는 스택에만 적용한다.
