# Prd MySQL 프록시 연결 가이드

> ⚠️ **프로덕션 DB입니다.** 조회 위주로 사용하고, 쓰기/스키마 변경은 절대 임의로 하지 마세요.

prd 클러스터에 socat 기반 MySQL 프록시(ClusterIP)가 배포되어 있습니다.
로컬 MySQL 클라이언트(IntelliJ, DBeaver 등)로 접근할 때 `kubectl port-forward`를 사용합니다.

## 간편 방법 — `acme` CLI

```bash
brew install acmecorp/tap/acme   # 최초 1회
acme pf prd               # acmemall(23307) + service(24306) 동시 터널
acme pf prd acmemall    # acmemall 만
acme pf prd service-clone # service 당일 클론
acme pf --status          # 상태 확인
acme pf --stop            # 종료
```

> 아래 수동 `kubectl port-forward` 명령은 동작 원리/디버깅용 참고입니다.

## 요약

> **모든 프록시 타겟은 `*-db.acme.example` CNAME 입니다.** RDS 엔드포인트가 바뀌어도(클러스터 재생성 등) 매니페스트는 그대로 두고 **Route53 레코드만 갱신**하면 됩니다. (호스티드존 `acme.example` = `Z0EXAMPLE0005`)

| acme 타겟 | K8s Service | 로컬 포트 | 원격 포트 | CNAME → 실제 대상 |
|-------------|-------------|-----------|-----------|-------------------|
| `acmemall` | `mall-mysql-service` | `23307` | `3306` | `acmemall-db.acme.example` → mall-prod-cluster |
| `service` | `venue-mysql-service` | `24306` | `4306` | `service-db.acme.example` → service-prod-cluster |
| `acme` | `acme-mysql-service` | `25308` | `3306` | `acme-db.acme.example` → acme-aurora ⚠️휴면 |
| `airflow` | `airflow-pg-service` | `25432` | `5432` | `airflow-db.acme.example` → airflow (postgres) |
| `beacon` | `beacon-pg-service` | `25433` | `5432` | `beacon-db.acme.example` → acme-beacon-pg (postgres) ⚠️휴면 |
| `acmemall-clone` | `mall-clone-mysql-service` | `25307` | `3306` | `acmemall-clone-db.acme.example` → 당일 클론 |
| `service-clone` | `service-clone-mysql-service` | `25306` | `3306` | `service-clone-db.acme.example` → 당일 클론 |

> - **service** 는 원격 포트가 **4306** (나머지 mysql은 3306)이니 주의. K8s Service 이름 `venue-mysql-service`는 과거 명명 잔재.
> - **클론**(`*-clone-db`)은 기존 `*-prod-clone-db.acme.example`(클론 스크립트가 매일 당일 클론으로 갱신)를 가리키는 CNAME 체인 → **항상 당일 클론에 연결**. 매니페스트/스크립트 수정 불필요.
> - **`acme` / `beacon`** 대상 클러스터(acme-aurora / acme-beacon-pg)는 현재 **인스턴스 0개(휴면, 백업 볼륨)** 라 접속 불가. 인스턴스 기동 시 CNAME이 자동 해석되어 바로 사용 가능 (프록시·CLI 미리 배선됨).
> - **postgres**(airflow/beacon) 매니페스트는 `manifests/postgres/prd/` 에 있습니다.
> - 로컬 포트는 dev(133xx)·prd 간 충돌하지 않게 분리.

### RDS 엔드포인트가 바뀌면 (운영 메모)
매니페스트 건드릴 필요 없이 Route53 레코드 값만 갱신:
```bash
aws route53 change-resource-record-sets --profile prd --hosted-zone-id Z0EXAMPLE0005 \
  --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"<name>-db.acme.example","Type":"CNAME","TTL":60,"ResourceRecords":[{"Value":"<new-rds-endpoint>"}]}}]}'
```

## 사전 준비

kubeconfig에 prd 클러스터가 `acme-prd` alias로 등록되어 있어야 합니다:

```bash
aws eks update-kubeconfig \
  --name acme-main-v2-prd \
  --alias acme-prd \
  --region ap-northeast-2
```

> ⚠️ `--alias` 없이 등록하면 context 이름이 ARN 전체(`arn:aws:eks:...`)로 등록되어
> `error: context "arn:aws:eks:..." does not exist` 에러가 발생할 수 있습니다.

## Port-forward 명령

### service MySQL (port 4306)

```bash
kubectl --context=acme-prd port-forward -n default svc/venue-mysql-service 24306:4306
```

접속: Host `127.0.0.1` / Port `24306`

### mall MySQL (port 3306)

```bash
kubectl --context=acme-prd port-forward -n default svc/mall-mysql-service 23307:3306
```

접속: Host `127.0.0.1` / Port `23307`

## 프록시 구조

```
로컬 MySQL 클라이언트
  └─ kubectl port-forward (로컬 포트 → K8s Service)
       └─ socat proxy pod (ClusterIP Service)
            └─ AWS RDS (service-prod-cluster... :4306 / mall-prod-cluster... :3306)
```

- 엔드포인트는 커스텀 도메인(`*.acme.example`)이 아니라 **AWS RDS 네이티브 클러스터 엔드포인트**를 직접 사용합니다.
  커스텀 도메인은 수동 관리 + 오매핑 위험이 있어 제거했습니다 (접근통제는 RDS 보안그룹이 담당).
- socat 프록시는 ClusterIP + `kubectl port-forward`(AWS 인증)로만 접근되어 **외부 노출이 없습니다.**

> 연결 검증: 2026-06-16 기준 두 DB 모두 handshake 정상 수신(MySQL 8.0.42).
