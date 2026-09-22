# AGENTS

이 저장소에서 작업하는 에이전트 공통 규칙입니다.

## 핵심 원칙
- 이 저장소는 GitOps 방식으로 운영한다.
- 클러스터 변경은 파일 수정 후 Git 반영으로 처리한다.
- Terraform apply/init/destroy는 CI/CD가 자동 처리한다. 로컬에서는 plan 확인과 state 조작(`state mv`/`import`)만 허용한다.
- `kubectl`은 읽기 명령(`get`, `describe`, `logs`, `top`, `exec`) 위주로 사용하고, 쓰기 명령은 긴급 복구 상황에서만 예외적으로 사용한다.

## Terraform 적용 규칙
- 코드 수정 → `git push` → CI/CD(`deploy.yml`)가 자동으로 plan + apply한다.
- 로컬에서 `terraform apply/init/destroy`를 직접 실행하지 않는다.
- 로컬에서 허용되는 작업: plan(확인용), `state mv`, `import`만 `terramate run ...` 경로로 실행한다.

## 드리프트 수정 원칙
- 기존 리소스/정책을 임의로 제거하거나 축소하지 않는다.
- AWS에 존재하지만 코드에 없는 리소스는 코드에 추가하는 방향(현실 → 코드)으로 처리한다.
- 코드에는 있지만 AWS에 없는 리소스는 사용자 확인 없이 임의 제거하지 않는다.

## Terramate 실행 메모리
- 공통 실행 플래그로 `--enable-sharing --mock-on-fail`를 기본 포함한다.
- 병렬도 기준은 `init: --parallel 1`, `plan: --parallel 5`를 우선 사용한다.
- 대상 스택 지정은 `--tags={env}:{stack}` 형식을 사용한다.
- 변경 스택만 실행할 때 `--changed`, destroy 시 역순 실행은 `--reverse`를 사용한다.

## ArgoCD/Helm 작업 규칙
- ArgoCD Application은 `argocd/{env}/...`에 정의한다.
- Helm values는 `values/{apps|infra}/...`에 둔다.
- Raw manifest는 `manifests/{app}/{env}/` 경로를 따른다.
- values 수정 전 해당 차트의 `_defaults.yaml`을 먼저 확인한다.
- ArgoCD 관련 변경(`argocd/`, `values/`, `manifests/`) 후에는 Sync 상태를 확인한다.
- Sync 확인은 `argocd app get <app-name> -o json` 기준으로 `Synced` + `Healthy`까지 확인한다.
- `OutOfSync`인 경우 `argocd app sync <app-name>`로 동기화를 트리거하고 원인을 확인한다.
- ArgoCD OIDC처럼 `configs.secret`에서 외부 시크릿을 참조하는 설정은 Secret 생성 경로(ExternalSecret/Terramate)를 함께 수정한다.
- ArgoCD 설치/업데이트 전에 참조되는 Secret 키가 먼저 생성되도록 순서를 보장한다.

## 네트워킹 규칙
- Traefik `IngressRoute`를 `manifests/traefik/{env}/`에서 관리하는 서비스는 Helm chart ingress를 기본적으로 비활성화한다.
- 동일 host/path를 Helm ingress와 Traefik IngressRoute로 중복 정의하지 않는다.

## 시크릿 규칙
- 평문 시크릿을 커밋하지 않는다.
- AWS Secrets Manager + External Secrets 패턴을 사용한다.

## AWS CLI 인증 규칙 (authentik OIDC)
- 장기 Access Key를 사용/커밋하지 않는다.
- 로컬 사람 인증은 authentik OIDC (Authorization Code + PKCE) 기반으로 처리한다.
  - 스크립트: `scripts/aws-oidc.sh` (`credential-process`)
  - 첫 실행: 브라우저 SSO 로그인. 이후: refresh_token 자동 갱신 (12시간)
- `~/.aws/config`에 `credential_process`로 등록하여 AWS CLI가 자동으로 토큰을 갱신한다.
- 로컬 설정 파일(`~/.aws/*`, 캐시 파일)은 절대 커밋하지 않는다.
- AWS 토큰이 만료되면 `make aws-login-dev` 또는 `make aws-login-prd`를 사용한다.
- `aws sso login`을 직접 실행하지 않는다.

## CLI 사용 규칙
- kubectl 컨텍스트 확인/전환은 `kubectx`를 우선 사용한다.

## 브랜치/커밋 규칙

### 브랜치 전략
- `main`이 ArgoCD가 바라보는 유일한 기준 브랜치다.
- 작업 유형별 브랜치 네이밍을 따른다: `feat/{scope}/{description}`, `fix/{scope}/{description}`, `chore/{scope}/{description}`, `hotfix/{description}`
  - 예: `feat/argo-workflows/add-chart`, `fix/stockroom-prd/db-env`, `hotfix/stockroom-prd-oom`
- ArgoCD `targetRevision`용 장기 브랜치는 `docs/reference/BRANCH_REVISION_POLICY.md`에 등록해야 한다.
- 파괴적 명령(`git reset --hard`, `git clean -f`, force push)은 사용하지 않는다.

### 커밋 메시지 형식
Conventional Commits를 따른다: `{type}({scope}): {description}`

| type | 용도 |
|------|------|
| `feat` | 새 앱/차트/스택/기능 추가 |
| `fix` | 잘못된 설정, 버그 수정 |
| `chore` | 버전업, 문서, 포맷, 정리 |
| `hotfix` | 긴급 장애 대응 |
| `refactor` | 동작 변경 없는 구조 개선 |

**언어**: description(제목)은 영어, 동사 원형으로 시작. body(본문)는 필요 시 한국어 허용.

scope는 변경 대상을 명시한다. `{app}`, `{app}/{env}`, `{infra-area}` 형식 사용.
- 예: `feat(argo-workflows): add helm chart`, `fix(stockroom/prd): correct DB_HOST`, `hotfix(stockroom/prd): increase memory to resolve OOM`

### 작업 유형별 브랜치 사용 기준

| 변경 유형 | 브랜치 | PR |
|-----------|--------|-----|
| 단일 앱·단일 환경 소규모 수정 (replicas, 환경변수, 이미지 태그 등) | `main` 직접 | 선택 |
| 신규 앱/차트 추가, 여러 앱/환경 동시 변경 | `feat/*` | 필수 |
| Terraform 인프라 변경 | `feat/*` 또는 `chore/*` | 필수 (plan 결과 description에 첨부) |
| 긴급 장애 대응 | `main` 직접 | 사후 이슈 생성 |

### 커밋 품질 기준
혼자 작업하더라도 커밋 메시지에 **why(이유)**를 남긴다. 변경 이유가 명확하지 않은 커밋은 장애 시 추적을 어렵게 만든다.
- values 파일에서 기본값과 다른 설정에는 주석으로 이유를 명시한다. 예: `# OOM으로 인해 512Mi로 증가 (2026-02-25)`

## 클러스터 대상 규칙
- 작업 대상 컨텍스트: `acme-main-v2-prd`, `acme-main-v2-dev`, `orbit-prd`, `orbit-dev`
- `acme-main-v2-prd`는 상용(`prd`) 환경이다.
- `acme-main-v2-dev`는 개발(`dev`) 환경이다.
- `aws-oidc.sh setup-config` 기준 EKS 컨텍스트 alias는 `acme-dev`, `acme-prd`를 사용한다.

## 도구/버전 규칙
- `terramate`는 `.tool-versions`의 고정 버전을 사용한다(현재 `0.14.7`).
- generated 파일은 수동 수정하지 않고 `terramate generate` 또는 `pre-commit run --all-files`로 갱신한다.
- 훅 실행 시 `asdf` shim 경로를 우선 사용해 버전 불일치를 방지한다.
- 셸 실행 전 `export PATH="$HOME/.asdf/shims:$PATH"`를 우선 적용한다.

## CI/GitHub Actions 메모리
- built-in `GITHUB_TOKEN`은 `permissions: actions: write`를 줘도 Actions variables REST API에 접근 불가(403 Resource not accessible by integration). 워크플로우가 상태를 저장해야 하면 전용 브랜치 + Contents API(`contents: write`)를 사용한다 (예: `workflow-state` 브랜치의 `state.json`).
- Terramate Cloud organization은 `acme-devops`이다.
- EKS 접근 IAM 역할명 기본값은 `GitHubActions`이다.
- backend profile(`dev`/`prd`)를 사용하므로 AWS named profile 구성을 유지한다.
- `GITHUB_TOKEN`은 step-level이 아니라 job-level env로 주입한다.
- Terramate Cloud GitHub Trust에서 repo/org 신뢰 구성을 확인한다.
- stack tags는 `dev`, `prd`를 사용한다.

## Worktree 작업 메모리
- 신규 앱/차트/스택 추가, 멀티파일 변경처럼 영향 범위가 큰 작업은 worktree에서 진행한다.
- worktree 브랜치 push 시 upstream tracking(`git push origin local-branch:remote-branch`)을 확인한다.
- worktree 세션에서는 bash cwd가 worktree로 리셋될 수 있으므로, 메인 레포 작업 시 절대경로로 `cd`해 확인한다.

## 스택 메모리
- 주요 스택: `tfstate`, `oidc`, `vpc`, `eks`, `addons`, `argocd-helm`, `karpenter-helm`, `argocd`, `karpenter`
- PIA 계열: `pia-albc`, `pia-ebs`, `pia-extdns`, `pia-extsec`, `pia-aiu`, `pia-mall`, `pia-venue`, `pia-web`, `pia-all`
- IAM/ECR: `iam-loki`, `iam-authentik`, `iam-authentik-saml`, `iam-authentik-oidc`, `ecr-stockroom`

## 운영 노하우 메모리
- Argo Workflows SSO(v3.7)는 `rbac.enabled: true`, SA/ClusterRoleBinding, `kubernetes.io/service-account-token` 타입 토큰 Secret까지 포함해야 한다.
- Argo Workflows v3.7에서 `/api/v1/info`의 `code:16`은 로그인 전 상태에서 정상 동작일 수 있다.
- Traefik v3 IngressRoute 매처는 `HeadersRegexp`가 아니라 `HeaderRegexp`를 사용한다.
- Authentik prd 리소스 기준은 server `cpu 1000m / memory 2Gi`, worker `cpu 500m / memory 1Gi`를 우선 적용한다.

## 긴급 수동 복구
- GitOps 원칙에 따라 `kubectl apply/create/patch/delete/edit/scale` 같은 쓰기 명령은 원칙적으로 사용하지 않는다.
- 단, 장애 상황 등 긴급한 수동 복구가 필요한 경우에 한해 예외적으로 허용하며, 사후에 반드시 Git 저장소에 변경사항을 반영해야 한다.
