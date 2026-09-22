# dev kubecost 복구 가이드

> dev 환경 kubecost 는 **2026-06-08 철거**됨. 나중에 다시 쓸 수 있어 복구 절차를 남김.
> (prd kubecost 는 영향 없음 — `values/infra/kubecost/prd.yaml` 등 그대로 유지)

## 무엇이 지워졌나 (= 복구용 영수증 PR)

| PR | 제거 대상 |
|----|-----------|
| #260 | kubecost ArgoCD Application (`argocd/dev/infra/ops/kubecost.yaml`), helm values (`values/infra/kubecost/dev.yaml`), ExternalSecret (`manifests/external-secrets/dev/es-kubecost-oauth2.yaml`), traefik ALB host + IngressRoute (`manifests/traefik/dev/`) |
| #262 | oauth2-proxy ArgoCD Application (`argocd/dev/infra/manifests/oauth2-proxy.yaml`) — dev 에선 kubecost SSO 리버스 프록시 전용이었음 |

## 복구 방법 (몇 분)

```bash
# devops-configs 레포에서
gh pr revert 260 && gh pr revert 262
# 머지 → root-app-v2 가 자동 re-sync → kubecost + oauth2-proxy 재기동
```

## 즉시 복구가 가능한 이유 (일부러 안 지운 것들)

- **AWS Secrets Manager** `eks/acme-main-dev` 의 `kubecost_oauth2_client_id` / `_client_secret` / `_cookie_secret` → 유지
- **Authentik OIDC application** (`https://sso.acme.example/application/o/kubecost/`) → 유지

→ 매니페스트만 되살리면 SSO 재설정 없이 `https://kubecost.dev.acme.example` 로그인까지 바로 동작.

## 주의

- ArgoCD `CreateNamespace=true` 는 네임스페이스를 만들기만 하고 prune 대상이 아님.
  철거 시 `kubecost` 네임스페이스가 빈 채로 남아 `kubectl delete ns kubecost` 수동 삭제가 필요했음.
  복구 시에는 `CreateNamespace=true` 가 다시 만들어주므로 별도 작업 불필요.
