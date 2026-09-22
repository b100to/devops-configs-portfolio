# AcmeCorp/services 로컬 bootRun 셋업

services 모놀리스 (Kotlin Spring Boot 3.5) 를 로컬 IntelliJ 에서 띄워 검증하는 방법.

> **왜 필요한가**: 머지 전 로컬 검증 필수 룰 ([.claude/CLAUDE.md §4-1](../../.claude/CLAUDE.md)). 클라우드 (K8s rollout) 로 검증하면 1회당 5-10분 — 너무 느림.

---

## TL;DR

```bash
# 1회 셋업 후
aws-oidc login dev          # 매 세션 토큰 만료 시
# IntelliJ ▶ ServicesApplication
curl http://localhost:8080/actuator/health
```

---

## 1회 셋업

### 1. kubefwd LaunchAgent

dev RDS / Kafka 가 private VPC 만 접근 가능 → **kubefwd** 가 K8s ClusterIP service 를 로컬 hostname 으로 매핑.

**plist 파일**: `~/Library/LaunchAgents/com.acme.kubefwd-dev.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.acme.kubefwd-dev</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/sudo</string>
        <string>-n</string>
        <string>/opt/homebrew/bin/kubefwd</string>
        <string>svc</string>
        <string>-n</string>
        <string>default</string>
        <string>-n</string>
        <string>kafka</string>
        <string>--context=acme-dev</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <!-- /sbin 필수 (ifconfig 위치) -->
        <string>/Users/user/.asdf/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin</string>
        <key>HOME</key>
        <string>/Users/user</string>
        <key>KUBECONFIG</key>
        <string>/Users/user/.kube/config</string>
    </dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key><false/>
        <key>Crashed</key><true/>
    </dict>
    <key>ThrottleInterval</key><integer>30</integer>
    <key>StandardOutPath</key><string>/tmp/kubefwd-dev.log</string>
    <key>StandardErrorPath</key><string>/tmp/kubefwd-dev.err</string>
</dict>
</plist>
```

### 2. sudoers NOPASSWD (kubefwd 가 sudo 없이 실행)

```bash
echo "$USER ALL=(ALL) NOPASSWD: /opt/homebrew/bin/kubefwd" | sudo tee /etc/sudoers.d/kubefwd
sudo chmod 440 /etc/sudoers.d/kubefwd
```

### 3. LaunchAgent 로드

```bash
launchctl unload ~/Library/LaunchAgents/com.acme.kubefwd-dev.plist 2>/dev/null
launchctl load -w ~/Library/LaunchAgents/com.acme.kubefwd-dev.plist
```

### 4. IntelliJ Run Configuration

ServicesApplication.kt main 우클릭 → **Modify Run Configuration**:

- **활성화된 프로파일**: `dev`
- **옵션 수정 → 환경 변수** 체크:

```
AWS_PROFILE=dev
DB_HOST=venue-mysql-service
DB_PORT=3306
ACMEMALL_DB_URL=jdbc:mysql://mall-mysql-service:3306/acme?serverTimezone=Asia/Seoul&characterEncoding=UTF-8
SPRING_KAFKA_PRODUCER_BOOTSTRAP_SERVERS=kafka.kafka:9092
SPRING_KAFKA_CONSUMER_BOOTSTRAP_SERVERS=kafka.kafka:9092
```

| Var | 효과 |
|---|---|
| `AWS_PROFILE=dev` | `/secret/services`, `/secret/dev_user` 등 SecretsManager 접근 |
| `DB_HOST=venue-mysql-service` | secret 의 RDS hostname 을 K8s ClusterIP proxy 로 override |
| `ACMEMALL_DB_URL=...mall-mysql-service:3306...` | acmemall datasource URL 전체 override |
| `SPRING_KAFKA_*BOOTSTRAP_SERVERS=kafka.kafka:9092` | Kafka K8s service alias |

> **`DB_USER`/`DB_PASSWORD` 박지 말 것** — secret 에서 가져옴. env 박으면 rotation 안 됨

### 5. 동작 확인

```bash
launchctl load -w ~/Library/LaunchAgents/com.acme.kubefwd-dev.plist
sleep 25
pgrep -fl "kubefwd svc"                              # 떠있는지
grep -E "venue-mysql|mall-mysql|kafka\." /etc/hosts # 등록됐는지
ping -c1 venue-mysql-service                        # routing 되는지
```

---

## 매 세션 작업

```bash
aws-oidc login dev   # 토큰 만료 시
```

그 후 IntelliJ ▶ 실행. startup 로그 끝에:
```
Started ServicesApplication in XX seconds
```

테스트:
```bash
curl http://localhost:8080/actuator/health
curl 'http://localhost:8080/recommendations/blogs-by-age?type=A&age=3'
```

---

## 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| `UnknownHostException: venue-mysql-service` | kubefwd 미기동. `pgrep -fl kubefwd` 확인, `launchctl load -w ...` 재시도 |
| `SocketTimeoutException: Connect timed out` | secret 의 RDS endpoint (private VPC IP) 로 직접 연결 시도. `DB_HOST` env var override 누락 |
| `ifconfig not found` (kubefwd 로그) | plist `PATH` 에 `/sbin` 누락 |
| `sudo: a password is required` (kubefwd 로그) | sudoers.d/kubefwd 누락 또는 권한 `440` 아님 |
| Kafka `No resolvable bootstrap urls` | `SPRING_KAFKA_*BOOTSTRAP_SERVERS` env var 미설정 또는 kafka ns 가 kubefwd 에 안 잡힘 |
| Kafka port 9092 conflict | 다른 kubefwd 인스턴스 실행 중. `sudo pkill -f kubefwd` 후 LaunchAgent reload |
| Spring Security 401 | `/recommendations/**` 등 permitAll path 만 인증 없이 접근. 다른 path 는 JWT 토큰 필요 |

---

## 왜 이렇게 복잡한가

| 이슈 | 이유 |
|---|---|
| Secret RDS endpoint 가 private | RDS 가 VPC 안에만 있음. cluster pod 은 직접 연결, 로컬은 못 닿음 |
| kubefwd 가 sudo 필요 | lo0 alias 추가 + /etc/hosts 수정 필요 |
| ifconfig 가 /sbin | macOS 표준 위치. LaunchAgent 의 PATH 가 minimal 이라 추가 필요 |
| Helm dev.yaml 의 `SPRING_KAFKA_*` 도 따라야 | Helm 이 박는 env 와 동일하게 맞춰야 cluster 와 동일 환경 |

---

## 관련 룰
- [.claude/CLAUDE.md §4-1](../../.claude/CLAUDE.md): **머지 전 로컬 테스트 필수**. 클라우드 검증으로 대체 금지
- memory `reference-local-bootrun-services`: 본 docs 의 메모리 사본
