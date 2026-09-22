# SSO 아키텍처

Authentik을 IdP로 사용하는 SSO 구성을 설명한다. 모든 내부 서비스와 AWS 접근은 Authentik을 통해 인증한다.

## 아키텍처 개요

```
Developer
  │
  ▼ HTTPS
Route53 (ExternalDNS 자동 관리)
  │
  ▼
AWS ALB (TLS 종료)
  │
  ▼
Traefik (IngressRoute 라우팅)
  │
  ├──→ Authentik (sso.acme.example)        ← IdP
  │
  ├──→ ArgoCD          ──OIDC──────────→ Authentik
  ├──→ Grafana         ──Generic OAuth──→ Authentik
  ├──→ Argo Workflows  ──OIDC──────────→ Authentik (+ Traefik Middleware)
  ├──→ Airflow         ──Flask OAuth───→ Authentik
  └──→ oauth2-proxy    ──OIDC──────────→ Authentik → Kubecost (reverse proxy)

AWS 접근:
  Authentik ──SAML──→ AWS Console (dev/prd)
  Authentik ──OIDC (PKCE)──→ AWS CLI (credential_process)

시크릿 주입:
  AWS Secrets Manager ──→ External Secrets Operator ──→ K8s Secret
    └── ArgoCD, Argo Workflows, Airflow, oauth2-proxy
```

## 컴포넌트별 SSO 방식

| 서비스 | 인증 방식 | Authentik Provider | 비고 |
|--------|-----------|-------------------|------|
| ArgoCD | OIDC | `argocd` (public) | CLI도 동일 provider 사용 |
| Grafana | Generic OAuth | `grafana` | |
| Argo Workflows | OIDC | `argo-workflows` | Traefik Middleware로 자동 리다이렉트 |
| Airflow | Flask OAuth | `airflow` | |
| Kubecost | OIDC (via oauth2-proxy) | `kubecost` | reverse proxy 모드 |
| AWS Console | SAML | `aws-console-dev`, `aws-console-prd` | |
| AWS CLI | OIDC (PKCE) | `aws-cli` | credential_process 연동 |

---

## 서비스별 설정 포인트

### ArgoCD

**인증 방식**: OIDC → Authentik

**핵심 결정: `argocd` provider를 `public`으로 설정**

Authentik은 per-application issuer를 사용한다. ArgoCD CLI용으로 별도 provider를 만들면 issuer가 달라져 토큰 검증이 실패한다. 따라서 웹/CLI 모두 동일한 `argocd` provider를 사용하고, provider를 `confidential → public`으로 변경한다.

- CLI와 웹 모두 `client_id=argocd` 사용
- 동일 issuer: `/application/o/argocd/`
- `cliClientID` 설정 불필요 (별도 provider 방식 작동 안 함)
- **redirect URI 추가 필수**: `argocd` provider에 `http://localhost:.*/auth/callback` (regex) 등록

```yaml
# ArgoCD values (SSO 설정 핵심)
server:
  config:
    oidc.config: |
      name: Authentik
      issuer: https://sso.acme.example/application/o/argocd/
      clientID: argocd
      # clientSecret: 없음 (public client)
      requestedScopes: ["openid", "profile", "email", "groups"]
```

관련 파일: `values/infra/argocd/{dev,prd}.yaml`

---

### Argo Workflows

**인증 방식**: OIDC → Authentik + Traefik Middleware (자동 리다이렉트)

#### RBAC 설정 (K8s 1.24+ 필수)

`rbac.enabled: true` 설정 시 SA token을 수동으로 생성해야 한다. 없으면 `code:7 "not allowed"` 에러가 발생한다.

```yaml
# SA token Secret (수동 생성 필수)
apiVersion: v1
kind: Secret
metadata:
  name: argo-workflows-server-token
  namespace: argo
  annotations:
    kubernetes.io/service-account.name: argo-workflows-server
type: kubernetes.io/service-account-token
```

```yaml
# rbac-rule: 모든 SSO 사용자 허용
server:
  sso:
    rbac:
      enabled: true
    rbacRule: '"true"'
    rbacRulePrecedence: "1"
```

#### SSO 자동 리다이렉트 (Traefik IngressRoute)

Argo Workflows는 미인증 사용자를 `/` 접근 시 SSO로 자동 리다이렉트해야 한다. Traefik의 쿠키 헤더 감지를 활용한다.

```yaml
routes:
  # Route 1 (priority 20): authorization 쿠키 있음 → 인증된 요청, 직접 전달
  - match: Host(`argo-workflows.acme.example`) && HeaderRegexp(`Cookie`, `authorization=`)
    priority: 20
    services:
      - name: argo-workflows-server
        port: 2746

  # Route 2 (priority 15): / 접근 → SSO 리다이렉트
  - match: Host(`argo-workflows.acme.example`) && Path(`/`)
    priority: 15
    middlewares:
      - name: argo-workflows-sso-redirect
        namespace: traefik
    services:
      - name: argo-workflows-server
        port: 2746

  # Route 3 (priority 10): 나머지 (SSO 콜백 등) → 직접 전달
  - match: Host(`argo-workflows.acme.example`)
    priority: 10
    services:
      - name: argo-workflows-server
        port: 2746
```

SSO 콜백 후 `authorization` 쿠키(HttpOnly)가 설정된다 → Route 1 매칭 → 무한 루프 없음.

관련 파일: `manifests/traefik/{env}/argo-workflows.yaml`

---

### Kubecost (oauth2-proxy)

**인증 방식**: oauth2-proxy(OIDC → Authentik) → Kubecost (reverse proxy)

oauth2-proxy가 Kubecost 앞단에 배치되어 인증을 처리한다. Kubecost 자체에는 인증 설정 없음.

**env var 방식 사용** (arg의 `$(VAR)` 확장은 컨테이너 런타임마다 동작이 달라 cookie signature mismatch 유발):

```yaml
env:
  - name: OAUTH2_PROXY_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: kubecost-oauth2-proxy
        key: client-id
  - name: OAUTH2_PROXY_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: kubecost-oauth2-proxy
        key: client-secret
  - name: OAUTH2_PROXY_COOKIE_SECRET
    valueFrom:
      secretKeyRef:
        name: kubecost-oauth2-proxy
        key: cookie-secret
```

**`--cookie-refresh` 주의**: `offline_access` scope + refresh token이 없으면 리다이렉트 루프 발생.

| 항목 | dev | prd |
|------|-----|-----|
| 도메인 | `kubecost.dev.acme.example` | `kubecost.acme.example` |
| oauth2-proxy 네임스페이스 | `traefik` | `traefik` |

관련 파일: `manifests/traefik/{env}/kubecost-oauth2.yaml`

---

### Authentik

**네임스페이스**: `authentik`
**도메인**: `sso.acme.example`

#### Application + Provider 관계

| 설정 | 동작 |
|------|------|
| Application에 provider 연결 | 포털에서 클릭 시 OAuth 플로우 시작 (같은 탭) |
| link-only (provider=None) | launch URL을 새 탭으로만 열기 |

oauth2-proxy 앱은 provider 분리 권장. provider를 연결하면 포털 클릭 시 oauth2-proxy 로그인 플로우가 시작되어 혼란을 줄 수 있다.

#### 리소스 요구사항

server CPU 500m 한도에서 throttle이 발생하여 readiness probe timeout → 재시작 → 503 사이클이 반복된 이력이 있다.

| 컴포넌트 | CPU request/limit | Memory request/limit |
|----------|-------------------|----------------------|
| server | 200m / 1000m | 512Mi / 2Gi |
| worker | 100m / 500m | 256Mi / 1Gi |

관련 파일: `values/infra/authentik/{dev,prd}.yaml`

---

## AWS 접근

### AWS Console (SAML)

Authentik SAML Provider(`aws-console-dev`, `aws-console-prd`)를 통해 AWS Console에 로그인한다.

스크립트: `scripts/aws-auth.sh`

그룹 권한:

| Authentik 그룹 | dev | prd |
|---------------|-----|-----|
| `devops-admin` | AdministratorAccess | AdministratorAccess |
| `developer` | PowerUserAccess | ReadOnlyAccess |

### AWS CLI (OIDC + credential_process)

Authorization Code + PKCE → Authentik → STS AssumeRoleWithWebIdentity. 상세 내용은 [aws-cli-oidc.md](./aws-cli-oidc.md) 참조.

```
aws-oidc.sh ──PKCE──→ Authentik (aws-cli provider)
                             │
                             └──→ id_token + refresh_token
                                          │
                                          ▼
                               AWS STS AssumeRoleWithWebIdentity
                                          │
                                          ▼
                               credential_process JSON → AWS CLI
```

- 토큰 캐시: `~/.cache/aws-oidc/` (STS 1h, refresh_token 12h)
- IAM Role: `authentik-oidc-admin` / `authentik-oidc-developer`
- 프로필: `dev-oidc` / `prd-oidc`

---

## 시크릿 관리

OAuth credentials는 AWS Secrets Manager에 저장하고 External Secrets Operator가 K8s Secret으로 동기화한다. 상세는 [secrets.md](./secrets.md) 참조.

| 서비스 | AWS Secrets Manager 키 | K8s Secret |
|--------|----------------------|------------|
| ArgoCD | `eks/acme-main-{env}` | `argocd-secret` |
| Argo Workflows | `eks/acme-main-{env}` | `argo-workflows-sso` |
| Airflow | `eks/acme-main-{env}` | `airflow-sso` |
| oauth2-proxy (Kubecost) | `eks/acme-main-{env}` | `kubecost-oauth2-proxy` |

---

## 트러블슈팅

### Authentik issuer 불일치로 토큰 검증 실패

**증상**: ArgoCD 로그인 후 `invalid token` 또는 CLI에서 인증 실패

**원인**: Authentik은 per-application issuer를 사용한다. ArgoCD CLI용으로 별도 provider(`cliClientID`)를 만들면 issuer가 달라진다.
- 웹 provider issuer: `/application/o/argocd/`
- 별도 CLI provider issuer: `/application/o/argocd-cli/`  ← 불일치

**해결**: `cliClientID` + 별도 provider 방식 제거. `argocd` provider를 `public`으로 변경해 웹/CLI 통합.

---

### Argo Workflows `code:7 "not allowed"`

**증상**: SSO 로그인 후 `code:7 desc="not allowed"` 에러

**원인**: K8s 1.24+에서는 SA token이 자동 생성되지 않는다. `rbac.enabled: true` 상태에서 SA token Secret이 없으면 권한 검증 실패.

**해결**: `kubernetes.io/service-account-token` 타입의 Secret을 수동 생성.

```bash
kubectl get secret -n argo argo-workflows-server-token
# 없으면 manifests/argo-workflows/{env}/sa-token.yaml 확인 후 git push
```

---

### oauth2-proxy 리다이렉트 루프

**증상**: Kubecost 접근 시 `/oauth2/start` ↔ `/oauth2/callback` 무한 반복

**원인 1**: `--cookie-refresh` 설정 시 `offline_access` scope가 없어 refresh token 미발급

**해결 1**: Authentik provider에 `offline_access` scope 추가, `--cookie-refresh` 제거하거나 scope 추가.

**원인 2**: cookie secret 불일치 (env var 대신 arg로 전달 시 발생 가능)

**해결 2**: env var 방식(`OAUTH2_PROXY_COOKIE_SECRET`)으로 통일. 쿠키명 변경으로 브라우저 캐시 문제 해결 가능.

---

### Traefik v3 HeaderRegexp 문법 오류

**증상**: Argo Workflows SSO 자동 리다이렉트가 작동하지 않음. Route 1 (priority 20)이 매칭되지 않음.

**원인**: Traefik v2 문법(`HeadersRegexp`) 사용. v3에서는 `HeaderRegexp` (단수형).

**해결**: IngressRoute의 모든 라우트 룰에서 `HeadersRegexp` → `HeaderRegexp` 변경.

```yaml
# 틀린 (v2)
- match: Host(`...`) && HeadersRegexp(`Cookie`, `authorization=`)

# 올바른 (v3)
- match: Host(`...`) && HeaderRegexp(`Cookie`, `authorization=`)
```

---

### Authentik 503 / 재시작 반복

**증상**: `sso.acme.example` 접근 시 산발적 503

**원인**: server CPU throttle → readiness probe timeout → Pod 재시작

**해결**: server CPU limit을 1000m으로 증가. 현재 prd 적정값: server 1000m / 2Gi, worker 500m / 1Gi.

```bash
# Authentik server CPU throttle 확인
kubectl top pod -n authentik
kubectl describe pod -n authentik -l app.kubernetes.io/name=authentik,app.kubernetes.io/component=server \
  | grep -A5 "Limits\|Requests"
```
