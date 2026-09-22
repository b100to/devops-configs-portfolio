# Networking

인터넷 트래픽이 서비스에 도달하는 경로와 관련 컴포넌트를 설명한다.

## 트래픽 흐름

```
인터넷
  │
  ▼
Route53 (ExternalDNS가 A record 자동 생성)
  │
  ▼
AWS ALB (internet-facing, TLS 종료)
  │   ├─ HTTPS 443 → HTTP 80 (TLS offload)
  │   └─ HTTP 80 → HTTPS 443 (ssl-redirect annotation)
  │
  ▼
Traefik (ClusterIP Service, NodePort → ALB target group)
  │   IngressRoute 규칙으로 라우팅
  │
  ▼
Service (각 네임스페이스)
  │
  ▼
Pod
```

Traefik은 TLS를 처리하지 않는다. ALB가 TLS를 종료하고 HTTP로 Traefik에 전달한다.
`X-Forwarded-For` 헤더는 VPC CIDR(`10.0.0.0/16`)에서 오는 경우만 신뢰한다.

## 컴포넌트

### Traefik

| 항목 | 값 |
|------|-----|
| Chart | `traefik/traefik` v38.0.0 |
| ArgoCD Application | `argocd/{env}/infra/networking/traefik.yaml` |
| Helm values | `values/infra/traefik/{dev,prd}.yaml` |
| Middleware/IngressRoute | `manifests/traefik/{env}/` |
| 네임스페이스 | `traefik` |

| 항목 | dev | prd |
|------|-----|-----|
| replicas (HPA) | 1–5 | 3–10 |
| CPU request/limit | 10m / 300m | 200m / 500m |
| Memory request/limit | 32Mi / 256Mi | 256Mi / 512Mi |
| PDB minAvailable | 1 | 2 |
| 접근 로그 | JSON | JSON |
| Prometheus metrics | 활성화 | 활성화 |

### AWS Load Balancer Controller

| 항목 | 값 |
|------|-----|
| Chart | `eks/aws-load-balancer-controller` v1.16.0 |
| ArgoCD Application | `argocd/{env}/infra/networking/aws-load-balancer-controller.yaml` |
| Helm values | `values/infra/aws-load-balancer-controller/{dev,prd}.yaml` |
| IAM 인증 | EKS Pod Identity |

### ExternalDNS

| 항목 | 값 |
|------|-----|
| Chart | `external-dns/external-dns` v9.0.3 |
| IAM 인증 | EKS Pod Identity |

ALB에 붙은 Ingress의 `external-dns.alpha.kubernetes.io/hostname` annotation을 읽어 Route53 A record를 자동 생성/삭제한다. 현재 dev/prd의 모든 도메인은 `manifests/traefik/{env}/alb.yaml` Ingress에서 관리된다.

---

## 새 서비스 노출 방법

### 1. IngressRoute 추가

`manifests/traefik/{env}/` 에 IngressRoute를 추가한다.

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-app
  namespace: my-namespace
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`my-app.dev.acme.example`)
      kind: Rule
      services:
        - name: my-app-service
          port: 8080
      middlewares:
        - name: company-ip-allowlist   # 사내 IP만 허용 시
          namespace: traefik
```

### 2. ALB hostname annotation에 도메인 추가

`manifests/traefik/{env}/alb.yaml` Ingress의 `external-dns.alpha.kubernetes.io/hostname` annotation에 새 도메인을 추가한다.

```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: >
    ...기존_도메인들...,
    my-app.dev.acme.example,    # 새 도메인 추가
```

### 3. git push

```bash
git add manifests/traefik/{env}/
git commit -m "feat(traefik/{env}): expose my-app service"
git push
```

ArgoCD `traefik-routes` Application이 자동으로 동기화하고, ExternalDNS가 Route53 레코드를 생성한다.

---

## Traefik Middleware 패턴

### IP Allowlist (사내 접근 제한)

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: company-ip-allowlist
  namespace: traefik
spec:
  ipAllowList:
    sourceRange:
      - "203.0.113.10/32"  # 회사 고정 IP (기존)
      - "203.0.113.20/32"    # 회사 고정 IP (신규 회선)
    ipStrategy:
      depth: 1                 # ALB가 X-Forwarded-For에 추가하는 깊이
```

IngressRoute에서 참조 시 네임스페이스를 명시한다.

```yaml
middlewares:
  - name: company-ip-allowlist
    namespace: traefik
```

### SSO 자동 리다이렉트 패턴

쿠키 유무로 인증 상태를 판단해 SSO 리다이렉트를 구현한다. (Argo Workflows 등에 적용)

```yaml
# Route 1 (priority 20): 이미 인증된 요청 → 직접 전달
- match: Host(`my-app.acme.example`) && HeaderRegexp(`Cookie`, `authorization=`)
  priority: 20
  services:
    - name: my-app
      port: 80

# Route 2 (priority 15): 루트 접근 → SSO 리다이렉트
- match: Host(`my-app.acme.example`) && Path(`/`)
  priority: 15
  middlewares:
    - name: sso-redirect
  services:
    - name: my-app
      port: 80

# Route 3 (priority 10): 나머지 → 직접 전달 (SSO 콜백 등)
- match: Host(`my-app.acme.example`)
  priority: 10
  services:
    - name: my-app
      port: 80
```

> **Traefik v3 주의**: `HeadersRegexp` (v2) → `HeaderRegexp` (v3 단수형). v2 문법 사용 시 라우트가 생성되지 않는다.

### redirectRegex Middleware

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: sso-redirect
  namespace: traefik
spec:
  redirectRegex:
    regex: "^https://my-app.acme.example/$"
    replacement: "https://sso.acme.example/oauth2/redirect?redirect=/"
    permanent: false
```

---

## ALB Annotation 주요 설정

```yaml
annotations:
  # 인터넷facing ALB, Pod IP로 직접 타겟
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
  alb.ingress.kubernetes.io/backend-protocol: HTTP

  # HTTP → HTTPS 리다이렉트
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
  alb.ingress.kubernetes.io/ssl-redirect: "443"

  # ACM 인증서 (콤마로 여러 개 지정 가능)
  alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."

  # Health check (Traefik /ping 엔드포인트)
  alb.ingress.kubernetes.io/healthcheck-path: /ping
  alb.ingress.kubernetes.io/healthcheck-port: "9000"
```

---

## 트러블슈팅

라우팅이 안 될 때 다음 순서로 확인한다.

### 1. Route53 레코드 확인

```bash
# ExternalDNS가 레코드를 생성했는지 확인
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Name=='my-app.dev.acme.example.']"
```

레코드가 없으면 `alb.yaml`의 hostname annotation에 도메인이 있는지 확인한다.

### 2. ALB 상태 확인

```bash
# ALB target group health 확인 (Traefik pod가 healthy해야 함)
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn>
```

unhealthy면 Traefik pod의 `/ping` 엔드포인트(port 9000)를 확인한다.

### 3. IngressRoute 확인

```bash
# IngressRoute 목록
kubectl get ingressroute -A

# 특정 라우트 상세
kubectl describe ingressroute <name> -n <namespace>
```

### 4. Traefik 로그 확인

```bash
# Traefik pod 로그 (JSON 형식)
kubectl logs -n traefik -l app=traefik --tail=100 | jq '.'

# 특정 호스트 필터
kubectl logs -n traefik -l app=traefik --tail=200 | \
  jq 'select(.RequestHost == "my-app.dev.acme.example")'
```

### 5. Middleware 참조 오류

네임스페이스 간 Middleware 참조 시 `namespace` 필드를 반드시 명시한다. 누락 시 Traefik이 라우트를 무시한다.

```yaml
# 올바른 참조
middlewares:
  - name: company-ip-allowlist
    namespace: traefik    # 반드시 명시
```
