# Dev MySQL 프록시 연결 가이드

dev 클러스터에 socat 기반 MySQL 프록시가 배포되어 있습니다.
로컬에서 MySQL 클라이언트(IntelliJ, DBeaver 등)로 접근할 때 `kubectl port-forward`를 사용합니다.

## 간편 방법 — `acme` CLI

```bash
brew install acmecorp/tap/acme   # 최초 1회
acme pf dev             # acmemall(13307) + service(13306) 동시 터널
acme pf dev acmemall  # acmemall 만
acme pf --status     # 상태 확인
acme pf --stop       # 종료
```

> 아래 수동 `kubectl port-forward` 명령은 동작 원리/디버깅용 참고입니다.

## 사전 준비

kubeconfig에 dev 클러스터가 `acme-dev` alias로 등록되어 있어야 합니다:

```bash
aws eks update-kubeconfig \
  --name acme-main-v2-dev \
  --alias acme-dev \
  --region ap-northeast-2
```

> ⚠️ `--alias` 없이 등록하면 context 이름이 ARN 전체(`arn:aws:eks:...`)로 등록되어
> `error: context "arn:aws:eks:..." does not exist` 에러가 발생할 수 있습니다.

## Port-forward 명령

### Venue MySQL

```bash
kubectl --context=acme-dev port-forward -n default svc/venue-mysql-service 13306:3306
```

연결 정보:
- Host: `127.0.0.1`
- Port: `13306`
- 실제 엔드포인트: `service-rds.dev.acme.example:3306`

### Mall MySQL

```bash
kubectl --context=acme-dev port-forward -n default svc/mall-mysql-service 13307:3306
```

연결 정보:
- Host: `127.0.0.1`
- Port: `13307`
- 실제 엔드포인트: `mall-rds.dev.acme.example:3306`

## 프록시 구조

```
로컬 MySQL 클라이언트
  └─ kubectl port-forward (로컬 포트 → K8s Service)
       └─ socat proxy pod (ClusterIP Service)
            └─ RDS (service-rds.dev.acme.example / mall-rds.dev.acme.example)
```
