# Airflow Green Upgrade 작업 리스트

작성일: 2026-05-06

## 목표

- 기존 운영 Airflow(`airflow`)에는 영향을 주지 않고 최신 Airflow를 green 환경으로 추가한다.
- green 환경은 ArgoCD가 관리하는 정식 GitOps 리소스로 배포한다.
- green 환경에서는 scheduler, triggerer, dagProcessor를 비활성화하여 DAG 실행 경로를 차단한다.
- green metadata DB는 운영 Aurora를 사용하지 않고, chart 내부 PostgreSQL pod를 사용한다.

## 현재 기준

| 항목 | blue 운영 | green 예정 |
|------|-----------|------------|
| ArgoCD Application | `airflow` | `airflow-green` |
| Helm release | `airflow` | `airflow-green` |
| Namespace | `airflow` | `airflow-green` |
| Helm chart | `apache-airflow/airflow` `1.15.0` | `apache-airflow/airflow` `1.21.0` |
| Airflow app version | `2.9.3` | `3.2.0` |
| Host | `airflow.acme.example` | `airflow-green.acme.example` |
| Metadata DB | 기존 Aurora | green namespace 내부 PostgreSQL pod |
| DAG 실행 | 활성 | 비활성 |

## 이번 작업 범위

### 1. 작업 브랜치 준비

- 신규 앱/멀티파일 변경이므로 worktree + 브랜치에서 작업한다.
- 브랜치 예시: `feat/airflow/add-green-upgrade`
- 기존 운영 파일은 가능한 한 수정하지 않는다.

### 2. Airflow chart defaults 갱신

- chart 버전 업그레이드 작업이므로 `_defaults.yaml`을 최신 chart 기준으로 갱신한다.

```bash
helm repo update apache-airflow
helm show values apache-airflow/airflow --version 1.21.0 > values/infra/airflow/_defaults.yaml
```

- 기존 운영 Application의 chart 버전은 변경하지 않는다.

### 3. Green values 추가

- 파일: `values/infra/airflow/prd-green.yaml`
- 기존 `prd.yaml`을 참고하되, 운영 리소스 이름과 secret을 재사용하지 않는다.

필수 설정:

```yaml
executor: KubernetesExecutor

config:
  core:
    base_url: https://airflow-green.acme.example
    load_examples: "False"

postgresql:
  enabled: true

scheduler:
  enabled: false

triggerer:
  enabled: false

dagProcessor:
  enabled: false

redis:
  enabled: false

flower:
  enabled: false
```

주의 사항:

- `data.metadataSecretName`으로 기존 `airflow-mate-db`를 참조하지 않는다.
- 기존 `airflow-secrets`, `airflow-aws-secret`, `airflow-dags-pvc`를 재사용하지 않는다.
- serviceAccount 이름은 `airflow-green-*` 패턴으로 분리한다.
- scheduler, triggerer, dagProcessor는 명시적으로 비활성화한다.

### 4. Green ArgoCD Application 추가

- 파일: `argocd/prd/infra/ops/airflow-green.yaml`
- 공식 Helm chart와 이 레포 values를 multi-source로 연결한다.

필수 값:

```yaml
metadata:
  name: airflow-green

spec:
  sources:
    - repoURL: https://airflow.apache.org/
      chart: airflow
      targetRevision: 1.21.0
      helm:
        releaseName: airflow-green
        valueFiles:
          - $values/values/infra/airflow/prd-green.yaml
  destination:
    namespace: airflow-green
```

### 5. Green SSO 분리

- 변경 파일 후보: `manifests/authentik/prd/blueprints.yaml`
- 변경 파일 후보: `manifests/authentik/prd/external-secret.yaml`
- 기존 Authentik `airflow` provider/client를 재사용하지 않는다.
- green 전용 Authentik application/provider를 추가한다.

권장 값:

| 항목 | 값 |
|------|----|
| provider slug | `airflow-green` |
| application slug | `airflow-green` |
| client_id | `airflow-green` |
| redirect URI | `https://airflow-green.acme.example/auth/oauth-authorized/authentik` |
| launch URL | `https://airflow-green.acme.example` |

Airflow green values의 `webserverConfig`도 green provider endpoint를 바라보게 한다.

```python
"client_id": "airflow-green",
"server_metadata_url": "https://sso.acme.example/application/o/airflow-green/.well-known/openid-configuration",
```

SSO 작업 체크리스트:

- Authentik OAuth provider를 `airflow-green`으로 새로 추가한다.
- Authentik Application을 `airflow-green`으로 새로 추가한다.
- redirect URI는 green host만 등록한다.
- launch URL은 green host만 등록한다.
- 기존 `airflow` provider/application/client_id/redirect URI는 변경하지 않는다.
- 기존 `airflow` app의 group binding, policy, launch URL은 변경하지 않는다.
- `values/infra/airflow/prd-green.yaml`의 `webserverConfig`에서 green provider endpoint를 사용한다.
- `AIRFLOW__WEBSERVER__OAUTH_CLIENT_SECRET`은 green 전용 secret에서 주입한다.
- Authentik `ExternalSecret`에 `AUTHENTIK_AIRFLOW_GREEN_OAUTH_SECRET`을 추가하고, Secrets Manager property `airflow_green_oidc_authentik_client_secret`에서 가져오게 한다.
- Authentik blueprint의 green provider는 `client_secret: !Env AUTHENTIK_AIRFLOW_GREEN_OAUTH_SECRET`을 사용한다.

### 6. Green secret 구성

- 평문 secret은 커밋하지 않는다.
- 필요 시 `ExternalSecret`을 green 전용으로 추가한다.
- 운영 `airflow-secrets`를 재사용하지 않는다.

Secrets Manager 확인 결과:

| Secret name | 용도 | 이번 green 사용 |
|-------------|------|-----------------|
| `eks/acme-main-v2-prd` | EKS/운영 앱 공용 secret bundle | green 전용 키만 추가해서 사용 |
| `eks/acme-main-prd` | 이전 prd 클러스터/레거시 secret bundle | 사용하지 않음 |
| `airflow/connections/*` | Airflow SecretsManagerBackend connection store. connection 단위로 너무 잘게 나뉜 상태 | green에서 bundle/import 방식 리허설 후보 |

`eks/acme-main-v2-prd`에 현재 존재하는 Airflow 관련 키:

- `AIRFLOW_AWS_ACCESS_KEY_ID`
- `AIRFLOW_AWS_SECRET_ACCESS_KEY`
- `AIRFLOW__CORE__FERNET_KEY`
- `AIRFLOW__WEBSERVER__SECRET_KEY`
- `argocd_oidc_authentik_client_secret`
- `connection`
- `connection_v3`

green에 필요한 신규 키:

| Secrets Manager property | Kubernetes Secret key | 이유 |
|--------------------------|-----------------------|------|
| `AIRFLOW_GREEN__CORE__FERNET_KEY` | `AIRFLOW__CORE__FERNET_KEY` | green 전용 fernet key. 운영 fernet key 재사용 금지 |
| `AIRFLOW_GREEN__API__SECRET_KEY` | `AIRFLOW__API__SECRET_KEY` 또는 chart `apiSecretKeySecretName` | Airflow 3+ API secret key |
| `AIRFLOW_GREEN__API_AUTH__JWT_SECRET` | `AIRFLOW__API_AUTH__JWT_SECRET` 또는 chart `jwtSecretName` | Airflow 3+ JWT signing secret |
| `airflow_green_oidc_authentik_client_secret` | `AIRFLOW__WEBSERVER__OAUTH_CLIENT_SECRET` | Authentik `airflow-green` OAuth client secret |

green에서는 chart 내부 PostgreSQL pod를 사용하므로 metadata DB secret은 만들지 않는다.

- `airflow-mate-db` 재사용 금지
- `connection` / `connection_v3` 재사용 금지
- `data.metadataSecretName`은 설정하지 않거나, 내장 PostgreSQL chart가 생성하는 값을 사용한다.

green에서 AWS Secrets Manager backend를 켤지 여부:

- 기본 green 기동/SSO/UI 검증만 할 때는 `AIRFLOW__SECRETS__BACKEND`를 끈다.
- DAG import 또는 connection 조회 검증이 필요해지는 후속 단계에서만 켠다.
- 후속 단계에서 켤 경우 운영과 같은 `airflow/connections` prefix를 읽게 되므로, scheduler/triggerer/dagProcessor가 꺼져 있는 상태에서만 검증한다.
- green 전용 connection store가 필요하면 `airflow-green/connections` prefix를 새로 설계한다.

ExternalSecret 후보:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: airflow-green-secrets
  namespace: airflow-green
spec:
  secretStoreRef:
    name: ss-airflow-green
    kind: SecretStore
  target:
    name: airflow-green-secrets
    creationPolicy: Owner
  data:
    - secretKey: AIRFLOW__CORE__FERNET_KEY
      remoteRef:
        key: eks/acme-main-v2-prd
        property: AIRFLOW_GREEN__CORE__FERNET_KEY
    - secretKey: AIRFLOW__API__SECRET_KEY
      remoteRef:
        key: eks/acme-main-v2-prd
        property: AIRFLOW_GREEN__API__SECRET_KEY
    - secretKey: AIRFLOW__API_AUTH__JWT_SECRET
      remoteRef:
        key: eks/acme-main-v2-prd
        property: AIRFLOW_GREEN__API_AUTH__JWT_SECRET
    - secretKey: AIRFLOW__WEBSERVER__OAUTH_CLIENT_SECRET
      remoteRef:
        key: eks/acme-main-v2-prd
        property: airflow_green_oidc_authentik_client_secret
```

주의:

- 위 신규 property들은 2026-05-06에 `eks/acme-main-v2-prd`에 추가했다.
- secret 값 생성/등록은 별도 수동 절차로 처리하고 평문을 커밋하지 않는다.
- Authentik 쪽 ExternalSecret에도 `AUTHENTIK_AIRFLOW_GREEN_OAUTH_SECRET` 매핑이 추가로 필요하다.
- Secrets Manager 리팩토링 시 우선 대상은 `airflow/connections/*` bundle/import 리허설이다. `eks/acme-main-v2-prd` 분리는 참고 원칙으로만 둔다. 목표 경로와 이관 순서는 [secrets-refactor.md](../reference/secrets-refactor.md)를 따른다.

### 7. Green route 추가

- 변경 파일 후보: `manifests/traefik/prd/infra.yaml`
- host: `airflow-green.acme.example`
- namespace: `airflow-green`
- service: chart render 결과 기준 green webserver service
- middleware: 기존과 동일하게 `company-ip-allowlist` 적용

기존 `airflow.acme.example` route는 변경하지 않는다.

Traefik route 작업 체크리스트:

- `airflow-green.acme.example` 전용 `IngressRoute`를 추가한다.
- `metadata.name`은 기존 `airflow`와 겹치지 않게 `airflow-green`으로 둔다.
- `metadata.namespace`는 `airflow-green`으로 둔다.
- service name은 Helm render 결과 기준으로 green webserver service를 사용한다.
- `airflow.acme.example` route는 변경하지 않는다.
- 기존 `airflow` namespace의 `IngressRoute`는 변경하지 않는다.
- 동일 host/path가 기존 `airflow.acme.example` 또는 다른 route와 중복되지 않는지 확인한다.

### 8. DAG 공급은 이번 작업에서 제외

- 기존 `acme-data`의 `.github/workflows/upload-dags-to-prod-s3-v2.yml`은 운영 blue 전용으로 유지한다.
- green 작업에서 기존 DAG upload workflow를 수정하거나 재사용하지 않는다.
- green에서 DAG import 검증이 필요하면 후속 작업으로 green 전용 DAG delivery를 설계한다.

이번 작업에서 참조 금지:

- namespace `airflow`
- PVC `airflow-dags-pvc`
- Job `airflow-dag-upload`
- serviceAccount `airflow-worker-sa`
- 기존 EFS ID 기반 운영 DAG 경로

### 8-1. DAG 호환성 검증 계획

이 단계는 Airflow 3.2.0에서 DAG import 호환성만 확인하는 작업이다. 운영 blue DAG 실행 경로에는 영향을 주지 않는다.

현재 DAG 소스 기준:

| 항목 | 값 |
|------|----|
| DAG repository | `acme-data` |
| DAG source path | `airflow_v2/dags/` |
| 운영 DAG workflow | `acme-data/.github/workflows/upload-dags-to-prod-s3-v2.yml` |
| 운영 target namespace | `airflow` |
| 운영 target PVC | `airflow-dags-pvc` |
| 운영 upload Job | `airflow-dag-upload` |

기존 workflow의 특징:

- `airflow_v2/dags/`를 운영 EFS PVC에 `rsync --delete`로 반영한다.
- target namespace가 `airflow`로 고정되어 있다.
- target PVC가 `airflow-dags-pvc`로 고정되어 있다.
- upload 후 운영 scheduler pod에 `scripts/reserialize_dags_v2.py`를 복사해 실행한다.
- EFS, StorageClass, PVC 생성 로직까지 workflow 안에 포함되어 있다.

따라서 green 검증에서는 이 workflow를 직접 수정하지 않는다. green 검증용 DAG delivery는 별도 workflow로 분리한다.

PR 작업 파일:

| Repository | 파일 | 역할 |
|------------|------|------|
| `devops-configs` | `argocd/prd/infra/manifests/airflow-green.yaml` | green 보조 manifest용 ArgoCD Application |
| `devops-configs` | `manifests/airflow-green/prd/dags-pvc.yaml` | green 전용 DAG PVC |
| `devops-configs` | `values/infra/airflow/prd-green.yaml` | green DAG PVC mount와 dagProcessor 활성화 |
| `acme-data` | `.github/workflows/validate-dags-airflow-green.yml` | 수동 실행 전용 green DAG 업로드 workflow |

권장 검증 순서:

1. `acme-data`에 green 전용 DAG 검증 workflow를 추가한다.
   - workflow 이름: `.github/workflows/validate-dags-airflow-green.yml`
   - trigger는 `workflow_dispatch`를 우선 사용한다.
   - 자동 push trigger는 초기에 걸지 않는다.
   - source는 `airflow_v2/dags/`를 그대로 사용한다.

2. green 전용 DAG 저장소를 분리한다.
   - namespace는 `airflow-green`을 사용한다.
   - PVC 이름은 `airflow-green-dags-pvc`처럼 blue와 겹치지 않게 둔다.
   - 운영 `airflow-dags-pvc`는 마운트하거나 갱신하지 않는다.
   - 기존 운영 EFS를 그대로 읽어야 하는 경우에도 green 전용 access point/PVC 여부를 먼저 검토한다.

3. `devops-configs`에서 green DAG mount 설정을 추가한다.
   - 대상 파일: `values/infra/airflow/prd-green.yaml`
   - `dags.persistence.enabled: true`로 전환한다.
   - `dags.persistence.existingClaim`은 green 전용 PVC만 참조한다.
   - `scheduler.enabled: false`는 유지한다.
   - `triggerer.enabled: false`는 유지한다.
   - DAG import 확인을 위해 `dagProcessor.enabled: true`, `replicas: 1`만 제한적으로 켠다.

4. green에서 import error를 확인한다.
   - UI의 DAG import error 화면을 확인한다.
   - `airflow-green` namespace의 api-server/dagProcessor 로그를 확인한다.
   - Airflow 3 provider 누락, deprecated import, FAB auth 관련 import 오류를 분리해 기록한다.

5. connection/variable 접근은 별도 단계로 검증한다.
   - DAG import만 확인하는 단계에서는 scheduler와 triggerer를 켜지 않는다.
   - connection secret backend를 켜야 하면 운영과 같은 prefix를 읽게 되는지 먼저 확인한다.
   - connection/variable import는 Airflow CLI export/import를 우선 사용하고 DB dump/restore는 피한다.

검증 완료 기준:

- `airflow-green`에 DAG 목록이 표시된다.
- import error가 없거나, Airflow 3 대응 이슈로 분류되어 있다.
- scheduler, triggerer는 계속 비활성 상태다.
- green DAG delivery가 운영 `airflow` namespace, `airflow-dags-pvc`, scheduler pod를 수정하지 않는다.

롤백:

- green values에서 `dags.persistence`와 `dagProcessor` 변경을 되돌린다.
- green 전용 DAG workflow만 비활성화하거나 revert한다.
- 운영 blue workflow와 PVC는 변경하지 않았으므로 운영 롤백 작업은 없다.

### 9. 렌더링 검증

Helm template으로 리소스 충돌 여부를 확인한다.

확인할 것:

- 기존 `airflow`와 같은 리소스 이름이 생성되지 않는지
- 기존 `airflow-mate-db` 문자열이 green render 결과에 없는지
- SSO 설정이 `airflow-green` provider/client/metadata URL을 바라보는지
- Traefik route가 `airflow-green.acme.example`만 추가하는지
- scheduler workload가 생성되지 않는지
- triggerer workload가 생성되지 않는지
- dagProcessor workload가 생성되지 않는지
- green PostgreSQL 리소스가 `airflow-green` namespace 기준으로 생성되는지

### 10. 배포 후 확인

ArgoCD 관련 변경 후에는 Sync 상태를 확인한다.

```bash
argocd app get airflow-green -o json | jq '{sync: .status.sync.status, health: .status.health.status}'
```

필요 시 sync를 트리거한다.

```bash
argocd app sync airflow-green
```

kubectl은 읽기 명령만 사용한다.

```bash
kubectx acme-prd
kubectl get pods -n airflow
kubectl get pods -n airflow-green
kubectl get svc -n airflow-green
```

확인할 것:

- 기존 `airflow` Application 상태 변화 없음
- `airflow-green` Application이 `Synced` + `Healthy`
- `airflow-green` namespace에 scheduler pod 없음
- `airflow-green` namespace에 triggerer pod 없음
- `airflow-green` namespace에 dagProcessor pod 없음
- green webserver 접근 가능
- green SSO 로그인 가능

## 진행 상태

### 2026-05-07 Green connection 리허설

운영 blue가 읽는 기존 `airflow/connections/{conn_id}` secret은 변경하지 않고, 신규 bundle secret에 값을 복제한 뒤 green metadata DB에만 import했다.

완료 항목:

- Secrets Manager bundle secret 4개에 connection 값을 복제했다.
  - `airflow/connections/core`
  - `airflow/connections/mall`
  - `airflow/connections/partner1`
  - `airflow/connections/recommendation`
- green DB에 connection 13개를 import했다.
- green에서 `airflow connections list` 기준 conn_id와 conn_type 조회를 확인했다.
- `airflow-green` namespace에 scheduler/triggerer deployment가 없는 상태를 재확인했다.
- `airflow-green-api-server`, `airflow-green-dag-processor`, `airflow-green-postgresql-0` pod가 Running 상태임을 확인했다.

import된 conn_id:

| conn_id | conn_type |
|---------|-----------|
| `gcp_conn_1` | `google_cloud_platform` |
| `aws_conn_1` | `aws` |
| `slack_conn_1` | `http` |
| `mall_conn_1` | `mysql` |
| `mall_live_conn_1` | `mysql` |
| `service_conn_1` | `mysql` |
| `partner1_conn_1` | `mysql` |
| `partner1_live_conn_1` | `mysql` |
| `partner1_conn_migration_1` | `mysql` |
| `partner1_conn_live_migration_1` | `mysql` |
| `partner1_conn_chunk` | `mysql` |
| `aws_conn_partner1_1` | `aws` |
| `recommendation_conn_1` | `mysql` |

주의:

- Airflow import 포맷에 맞추기 위해 AWS/GCP connection은 green import 파일 생성 시 `extra_dejson` 형태로 변환했다.
- 이 변환은 green DB import 리허설용이며, 기존 Secrets Manager source secret 값은 변경하지 않았다.
- 값은 문서와 git에 남기지 않는다.

## 이번 작업에서 제외

아래 항목은 이번 Airflow green 추가 작업에 포함하지 않는다.

- EFS 생성 Terraform 전환
- SecurityGroup 생성 Terraform 전환
- StorageClass/PVC ArgoCD adoption
- 기존 `acme-data` DAG upload workflow 수정
- 기존 운영 DAG delivery 구조 변경
- 기존 운영 metadata DB migration
- `airflow.acme.example` cutover

## 후속 작업 후보

### DAG Delivery v3 설계

현재 `acme-data`의 DAG upload workflow는 EFS, StorageClass, PVC, Job, scheduler rescan까지 한 번에 처리한다. 장기적으로는 책임을 분리한다.

권장 방향:

- `devops-configs`: EFS, Access Point, StorageClass, PVC, ServiceAccount, RBAC, syncer 관리
- `acme-data`: DAG validation + artifact upload만 담당
- blue/green DAG 채널 분리
- kubectl write 제거
- scheduler pod 직접 조작 제거

### 기존 리소스 코드화

이미 만들어진 리소스는 새로 만들지 않고, 필요에 따라 다음 방식 중 하나를 선택한다.

- Terraform이 lifecycle을 소유해야 하면 `import`
- 외부/레거시 리소스로 유지해야 하면 `data source`
- Kubernetes 리소스는 실제 spec 확인 후 ArgoCD adoption 여부를 별도 판단

대상 후보:

- EFS filesystem
- EFS mount target
- EFS security group
- EFS access point
- StorageClass
- PVC

### Cutover 계획

green 검증 완료 후 별도 작업으로 진행한다.

- green에서 scheduler/triggerer/dagProcessor 활성화 조건 정의
- 운영 metadata DB migration 전략 수립
- DAG delivery green 경로 검증
- `airflow.acme.example` route 전환
- rollback route 준비

## 안전 원칙

- 기존 운영 `airflow` Application, namespace, DB, route, DAG PVC를 건드리지 않는다.
- green은 운영 전환 후보가 아니라 최신 버전 검증용 sandbox로 시작한다.
- 운영 트래픽 전환은 자동화하지 않고 별도 승인 후 진행한다.
- 클러스터 변경은 파일 수정 후 Git 반영으로 처리한다.
