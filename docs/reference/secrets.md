# Secret Management

AWS Secrets Manager에 저장된 시크릿을 External Secrets Operator(ESO)를 통해 K8s Secret으로 동기화한다.

## 아키텍처

```
AWS Secrets Manager
  └── eks/acme-main-{env}  (JSON 형태로 key-value 저장)
          │
          │  (Pod Identity로 인증)
          ▼
  ClusterSecretStore (aws-secrets-store)
          │
          │  (ExternalSecret이 참조)
          ▼
  ExternalSecret CRD
          │
          │  (15분마다 sync)
          ▼
  K8s Secret (각 네임스페이스)
          │
          ▼
  Pod (env or volume mount)
```

## 구성 요소

| 항목 | 내용 |
|------|------|
| Helm chart | `external-secrets/external-secrets` v0.14.0 |
| ArgoCD Application | `argocd/{env}/infra/manifests/external-secrets.yaml` |
| ExternalSecret 매니페스트 | `manifests/external-secrets/{env}/` |
| Helm values | `values/infra/external-secrets/{dev,prd}.yaml` |
| sync interval | `refreshInterval: 15m` |

## IAM 인증 (Pod Identity)

IRSA 방식이 아닌 EKS Pod Identity를 사용한다.

| 환경 | IAM Role ARN |
|------|-------------|
| dev | `arn:aws:iam::111111111111:role/eks-pod-identity-external-secrets-v2` |
| prd | `arn:aws:iam::222222222222:role/eks-pod-identity-external-secrets-v2` |

Role ARN은 Helm values의 serviceAccount annotation으로 설정된다.

```yaml
# values/infra/external-secrets/dev.yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::111111111111:role/eks-pod-identity-external-secrets-v2"
```

## ClusterSecretStore

모든 네임스페이스에서 `aws-secrets-store` 이름의 ClusterSecretStore를 사용한다. ClusterSecretStore 리소스 자체는 external-secrets Helm chart가 설치되면서 생성된다 (values 파일에 정의).

```yaml
secretStoreRef:
  name: aws-secrets-store
  kind: ClusterSecretStore
```

## 현재 사용 중인 시크릿

상세 리팩토링 방향과 신규 naming convention은 [secrets-refactor.md](./secrets-refactor.md)를 따른다. 우선 실행 대상은 `airflow/connections/*`처럼 너무 잘게 나뉜 secret을 green에서 bundle/import 방식으로 리허설하는 것이다. `eks/acme-main-*` 같은 큰 legacy bundle 분리는 장기 참고 원칙으로 두고 즉시 진행하지 않는다.

| 네임스페이스 | ExternalSecret 파일 | AWS Secrets Manager 키 |
|-------------|-------------------|----------------------|
| `argo` | `es-argo-workflows.yaml` | `eks/acme-main-dev` |
| `monitoring` | `monitorning.yaml` | `eks/acme-main-v2-dev` |
| `mall` | `mall.yaml` | (mall 관련 키) |
| `venue` | `venue.yaml` | (venue 관련 키) |
| `airflow` (prd) | `es-airflow.yaml` | (airflow 관련 키) |
| `traefik` | `es-kubecost-oauth2.yaml` | (oauth2 관련 키) |

---

## 새 시크릿 추가 방법

### 1. AWS Secrets Manager에 값 추가

기본적으로 owner/rotation/access boundary가 같은 값은 하나의 domain bundle로 묶는다. 기존 JSON bundle에 key를 추가하는 방식은 legacy 호환이 필요한 경우에만 사용한다.

```bash
# 기존 시크릿에 key 추가
aws secretsmanager get-secret-value \
  --secret-id eks/acme-main-dev \
  --query SecretString --output text | jq '.'

# 값 업데이트 (기존 내용에 머지)
aws secretsmanager update-secret \
  --secret-id eks/acme-main-dev \
  --secret-string '{"my_new_key": "my_value", ...기존_내용...}'
```

신규 secret 이름 예시:

```text
{domain}/{purpose}
```

예:

```text
airflow/connections/mall
```

### 2. ExternalSecret 매니페스트 작성

`manifests/external-secrets/{env}/` 에 파일을 추가한다.

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-app-secret
  namespace: my-namespace
spec:
  refreshInterval: "15m"
  secretStoreRef:
    name: aws-secrets-store
    kind: ClusterSecretStore
  target:
    name: my-app-secret        # 생성될 K8s Secret 이름
    creationPolicy: Owner       # ESO가 소유권 관리
  data:
    - secretKey: MY_ENV_VAR    # K8s Secret의 key
      remoteRef:
        key: my-app/core             # AWS Secrets Manager secret 이름
        property: my-new-key         # JSON 내 field 이름
```

여러 key를 한 번에 가져올 경우 `dataFrom`을 사용한다.

```yaml
spec:
  dataFrom:
    - extract:
        key: eks/acme-main-dev   # JSON 전체를 K8s Secret으로 변환
```

### 3. git push

```bash
git add manifests/external-secrets/{env}/
git commit -m "feat(external-secrets): add ExternalSecret for my-app"
git push
```

ArgoCD `manifests-external-secrets` Application이 자동으로 동기화한다.

---

## 트러블슈팅

### sync 실패 확인

```bash
# ExternalSecret 상태 확인
kubectl get externalsecret -n <namespace>
kubectl describe externalsecret <name> -n <namespace>

# 조건 확인 — "SecretSynced" 상태여야 정상
kubectl get externalsecret <name> -n <namespace> \
  -o jsonpath='{.status.conditions[*]}'
```

### 주요 에러 패턴

| 에러 | 원인 | 해결 |
|------|------|------|
| `SecretNotFound` | AWS Secrets Manager에 키 없음 | 시크릿 생성 또는 키 추가 |
| `AccessDenied` | IAM Role에 권한 없음 | Role Policy 확인 |
| `InvalidSecretName` | `key` 또는 `property` 오타 | AWS Console에서 실제 키 이름 확인 |
| `ClusterSecretStore not ready` | ESO Pod 미기동 | `kubectl get pods -n external-secrets` |

### 수동 즉시 동기화

refreshInterval을 기다리지 않고 즉시 sync 트리거:

```bash
# annotation 추가로 즉시 sync
kubectl annotate externalsecret <name> -n <namespace> \
  force-sync=$(date +%s) --overwrite
```

---

## 보안 원칙

- **평문 시크릿 git 커밋 금지** — 반드시 AWS Secrets Manager를 경유할 것
- K8s Secret은 ESO가 `Owner`로 관리 — 직접 수정하지 않는다 (다음 sync 시 덮어씌워짐)
- 시크릿 값 변경 시 AWS Secrets Manager만 수정하면 15분 내 자동 반영
