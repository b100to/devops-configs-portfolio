# Airflow Connection Secrets 리팩토링 계획

작성일: 2026-05-06

## 배경

현재 운영 Airflow는 SecretsManagerBackend를 사용해 `airflow/connections/{conn_id}` 경로의 secret을 직접 조회한다. 이 방식은 Airflow 기본 동작과 잘 맞지만, connection 하나마다 Secrets Manager secret이 하나씩 생겨 inventory, tag, Terraform 관리, 변경 추적이 번잡해진다.

이번 계획의 범위는 Airflow connection secret 정리다. `eks/acme-main-v2-prd` 같은 큰 공용 bundle 분해나 Authentik/Kubecost/Datadog secret 재배치는 이번 작업에 포함하지 않는다.

확인된 문제:

- `airflow/connections/*`는 Airflow SecretsManagerBackend와 호환되지만, connection 단위 secret이 많아져 inventory와 변경 관리가 번잡하다.
- 확인한 `airflow/connections/*` secret은 모두 JSON 형태라 bundle화 리허설이 가능하다.
- 운영 blue는 현재 `airflow/connections/{conn_id}`를 직접 조회하므로 기존 secret을 바로 합치거나 삭제하면 안 된다.
- `rds!cluster-*`는 AWS RDS managed secret이라 Airflow connection bundle 정리 대상이 아니다.

## 목표

- `airflow/connections/*`를 domain bundle 후보로 재배치한다.
- green에서 먼저 bundle을 읽어 Airflow DB에 import하는 방식을 리허설한다.
- 운영 blue의 기존 SecretsManagerBackend 직접 조회 경로는 유지한다.
- Terraform은 Secret 값이 아니라 Secret container, tag, policy, rotation 같은 lifecycle만 관리한다.
- 평문 secret은 git과 Terraform state에 넣지 않는다.

## Naming Convention

신규 AWS Secrets Manager secret 이름은 아래 형식을 우선 사용한다. prd AWS account 안에서는 `acme/prd` prefix를 생략한다.

```text
{domain}/{purpose}
```

예시:

```text
airflow/connections/core
airflow/connections/partner1
airflow/connections/mall
airflow/connections/recommendation
```

권장 JSON property 이름:

- 앱 내부 env 이름을 그대로 쓰지 않고, secret 목적을 짧게 표현한다.
- 같은 secret 안에서는 kebab-case를 우선 사용한다.
- K8s Secret key 이름은 ExternalSecret에서 앱이 기대하는 env/key 이름으로 변환한다.

예:

```yaml
remoteRef:
  key: airflow/connections/mall
  property: mall_conn_1
```

```yaml
secretKey: AIRFLOW_CONNECTIONS_MALL_BUNDLE
```

## 분류 기준

| 분류 | 예시 | 관리 방향 |
|------|------|-----------|
| Airflow connections | DAG runtime connection JSON | `airflow/connections/{domain}` |
| AWS managed secret | `rds!cluster-*` | 리팩토링 제외. AWS owning service가 관리한다. |

## Terraform 관리 범위

Terraform이 관리한다:

- `aws_secretsmanager_secret`
- `aws_secretsmanager_secret_version`은 사용하지 않는다. 값은 Terraform state에 넣지 않는다.
- KMS key/policy
- resource policy
- tags
- rotation 설정
- import/data source를 통한 기존 secret ownership 정리

Terraform이 관리하지 않는다:

- `aws_secretsmanager_secret_version`의 실제 값
- Airflow connection JSON 값
- 기존 connection secret에서 bundle secret으로 값을 복제하는 작업

값을 Terraform state에 넣어야 하는 예외가 생기면 PR description에 이유와 state 노출 리스크를 명시한다.

신규 secret container 생성은 Terraform PR로 처리한다. PR에는 plan 결과를 첨부하고, apply는 CI/CD가 수행한다. 값 복제는 별도 운영 절차로 처리한다.

Airflow connection bundle secret container는 아래 스택에서 관리한다.

```text
stacks/acme/secrets/airflow-connections/prd
```

권장 tag:

| Tag | 예시 |
|-----|------|
| `Environment` | `prd` |
| `Application` | `airflow` |
| `Owner` | `data-platform` |
| `ManagedBy` | `terraform` |
| `SecretClass` | `airflow-connection-bundle` |
| `Rotation` | `manual`, `automatic` |

`ReplacementFor` 같은 다중 매핑 정보는 AWS tag에 넣지 않고 inventory 문서에 남긴다. AWS tag value는 서비스별 허용 문자 제약이 다르고, 여러 legacy secret을 쉼표로 묶으면 Secrets Manager 생성이 실패할 수 있다.

## 이관 순서

1. Inventory를 만든다.
   - `ExternalSecret` name/namespace
   - `remoteRef.key`
   - `remoteRef.property`
   - target K8s Secret
   - consumer app/chart
   - owner
   - rotation 여부

2. 신규 secret container를 만든다.
   - Terraform 또는 기존 리소스 import/data source를 사용한다.
   - secret 값은 별도 절차로 AWS Secrets Manager에 주입한다.

3. 값을 복제한다.
   - 기존 `airflow/connections/{conn_id}` 값을 새 bundle secret에 복제한다.
   - 값 자체는 문서나 git에 남기지 않는다.

4. ExternalSecret만 전환한다.
   - K8s Secret 이름은 유지한다.
   - `remoteRef.key/property`만 새 경로로 바꾼다.

5. consumer를 검증한다.
   - ExternalSecret condition이 `SecretSynced`인지 확인한다.
   - app rollout/reload가 필요한지 확인한다.

6. 기존 connection secret을 deprecated 후보로 표시한다.
   - 바로 삭제하지 않는다.
   - replacement, owner, 제거 가능 일자를 inventory에 남긴다.

7. 일정 기간 후 삭제한다.
   - 해당 property 참조가 repo와 cluster에 없는지 확인한 뒤 제거한다.

## Airflow Connection 파일럿

우선 실행 대상은 `airflow/connections/*` 정리다. 이 항목은 이미 connection 단위로 너무 잘게 나뉘어 있고, 확인 결과 모든 connection secret이 JSON 형태라 bundle화 리허설이 가능하다.

현재 운영 blue Airflow는 다음 설정으로 Secrets Manager를 직접 조회한다.

```yaml
AIRFLOW__SECRETS__BACKEND: airflow.providers.amazon.aws.secrets.secrets_manager.SecretsManagerBackend
AIRFLOW__SECRETS__BACKEND_KWARGS: '{"connections_prefix": "airflow/connections", "variables_prefix": "airflow/variables", "cache": false}'
```

따라서 기존 `airflow/connections/{conn_id}` secret을 바로 합치면 운영 blue가 connection을 찾지 못할 수 있다. 합치는 작업은 green에서 먼저 `airflow connections import` 방식으로 리허설한다.

현재 connection secret:

| Current secret | Shape | 비고 |
|----------------|-------|------|
| `airflow/connections/gcp_conn_1` | JSON | keys only verified |
| `airflow/connections/aws_conn_1` | JSON | keys only verified |
| `airflow/connections/partner1_live_conn_1` | JSON | keys only verified |
| `airflow/connections/slack_conn_1` | JSON | keys only verified |
| `airflow/connections/partner1_conn_migration_1` | JSON | keys only verified |
| `airflow/connections/recommendation_conn_1` | JSON | keys only verified |
| `airflow/connections/partner1_conn_1` | JSON | keys only verified |
| `airflow/connections/mall_live_conn_1` | JSON | keys only verified |
| `airflow/connections/mall_conn_1` | JSON | keys only verified |
| `airflow/connections/service_conn_1` | JSON | keys only verified |
| `airflow/connections/aws_conn_partner1_1` | JSON | keys only verified |
| `airflow/connections/partner1_conn_live_migration_1` | JSON | keys only verified |
| `airflow/connections/partner1_conn_chunk` | JSON | keys only verified |

목표 bundle 후보:

| New secret | 포함 대상 |
|------------|----------|
| `airflow/connections/core` | `gcp_conn_1`, `aws_conn_1`, `slack_conn_1` |
| `airflow/connections/mall` | `mall_conn_1`, `mall_live_conn_1`, `service_conn_1` |
| `airflow/connections/partner1` | `partner1_conn_1`, `partner1_live_conn_1`, `partner1_conn_migration_1`, `partner1_conn_live_migration_1`, `partner1_conn_chunk`, `aws_conn_partner1_1` |
| `airflow/connections/recommendation` | `recommendation_conn_1` |

리허설 방식:

1. Terraform으로 새 bundle secret container를 만든다.
2. 기존 `airflow/connections/{conn_id}` 값을 bundle JSON으로 복제한다. 값 복제는 Terraform이 아니라 별도 운영 절차로 수행한다.
3. green에서 bundle을 읽어 Airflow DB에 import하는 Job을 만든다.
4. green UI/CLI에서 connection 조회를 확인한다.
5. 운영 blue의 SecretsManagerBackend 전환 여부는 별도 결정한다.

주의:

- 운영 blue의 `airflow/connections/{conn_id}` secret은 리허설 단계에서 삭제하지 않는다.
- green scheduler/triggerer가 꺼진 상태에서 connection import만 검증한다.
- bundle import가 안정화되기 전까지 운영 blue는 기존 SecretsManagerBackend 직접 조회를 유지한다.
- `rds!cluster-*` secret은 AWS RDS managed secret이라 이 작업에서 제외한다.

## 신규 key 추가 규칙

- 신규 앱/기능은 가능한 한 legacy bundle에 property를 추가하지 않는다.
- 예외가 필요하면 PR에 이유와 제거 계획을 남긴다.
- Airflow connection bundle path가 이미 있으면 그 경로를 사용한다.
- Authentik, Kubecost, Datadog 등 다른 앱 secret 재배치는 이번 PR 범위에 포함하지 않는다.

## Inventory 템플릿

```markdown
| Env | Namespace | ExternalSecret | Target Secret | remoteRef.key | remoteRef.property | Consumer | Owner | Status | Replacement |
|-----|-----------|----------------|---------------|---------------|--------------------|----------|-------|--------|-------------|
| prd | airflow | Airflow SecretsManagerBackend | connection | airflow/connections/mall_conn_1 | JSON secret | Airflow DAG runtime | data-platform | split-too-fine | airflow/connections/mall:mall_conn_1 |
```
