# DevOps Configurations (GitOps)

이 저장소는 **GitOps** 방식으로 관리됩니다. 모든 변경은 Git을 통해서만 이루어집니다.

## 📌 "명시해" 키워드 (글로벌 규칙 재확인)

사용자가 **"명시해"** 라고 하면 **3곳 모두 업데이트**:
1. 글로벌 CLAUDE.md (`~/.claude/CLAUDE.md`)
2. 프로젝트 CLAUDE.md (이 파일)
3. memory (`MEMORY.md` 인덱스 + `memory/*.md` 본문)

상세는 글로벌 CLAUDE.md 최상단 참조. 메모리만 업데이트하고 끝내지 말 것.

## 🚨 핵심 규칙

### 절대 금지
```bash
# ❌ kubectl 쓰기 명령 전면 금지 (사용자가 명시적으로 요청해도 한 번 더 확인)
kubectl apply ...
kubectl create ...
kubectl patch ...
kubectl delete ...
kubectl edit ...
kubectl set ...
kubectl rollout restart ...
kubectl scale ...

# ❌ Terraform 직접 실행 금지
cd stacks/... && terraform init/plan/apply
```
> **kubectl은 읽기 전용으로만 사용** (`get`, `describe`, `logs`, `top`, `exec` 등)
> 클러스터 상태 변경이 필요하면 반드시 **파일 수정 → git push → ArgoCD 싱크** 또는 **git push → CI/CD 자동 적용** 경로를 사용할 것

### Terraform 적용 규칙
코드 수정 → `git push` → CI/CD (`deploy.yml`)가 자동으로 plan + apply.
```bash
# ✅ 올바른 방법: 코드 수정 후 push → CI/CD 자동 적용
git add . && git commit && git push

# ❌ 로컬에서 plan/init 실행 금지 — PR CI(deploy.yml)가 권위 plan+apply 수행
#    변경 영향은 PR의 CI plan 결과로 확인한다 (로컬 plan은 느리고 plugin timeout 등 잡음만)
#    (사용자 지시: "PR에서 알아서 CI 돌아갈텐데 왜 로컬에서 테스트함 이제부터 하지마")

# ✅ CI/CD로 처리 불가능한 작업만 로컬 실행 허용 (state mv, import)
terramate run --tags=prd:pia-albc --enable-sharing --mock-on-fail -- \
  terraform state mv 'old.resource' 'new.resource'
terramate run --tags=prd:eks --enable-sharing --mock-on-fail -- \
  terraform import 'resource.addr' 'resource-id'

# ❌ 로컬에서 plan/apply/init 직접 실행 금지 (CI/CD가 처리)
# ❌ cd로 스택 이동 후 직접 실행 금지
```

### 드리프트 수정 원칙
**기존 리소스/정책을 제거하거나 축소하지 않는다.**
- AWS에 존재하지만 코드에 없는 것 → **코드에 추가** (현실 → 코드)
- 코드에 있지만 AWS에 없는 것 → **사용자 확인 후 판단** (임의 제거 금지)
- 드리프트 = "코드와 현실의 차이"이며, 기본 방향은 **현실에 맞게 코드를 수정**하는 것

**주요 플래그:**
| 플래그 | 용도 |
|--------|------|
| `--tags={env}:{stack}` | 대상 스택 지정 |
| `--enable-sharing --mock-on-fail` | 스택 간 output 공유 (항상 포함) |
| `--parallel N` | 병렬 실행 (init: 1, plan: 5) |
| `--changed` | 변경된 스택만 |
| `--reverse` | 역순 실행 (destroy 시) |
| `--continue-on-error` | 에러 시 계속 진행 |

### Bash 환경 (asdf)
이 레포의 CLI 도구(`terramate`, `terraform` 등)는 **asdf**로 관리됨. Bash 실행 시 PATH에 asdf shims를 포함할 것:
```bash
export PATH="$HOME/.asdf/shims:$PATH"
```
> 모든 Bash 명령 실행 전 위 PATH가 설정되어 있어야 `terramate`, `terraform` 등을 찾을 수 있음

### AWS 로그인
AWS 명령(`aws`, `kubectl`, `eks update-kubeconfig` 등) 실행 전 토큰 만료 시:
```bash
aws-oidc login dev   # dev 환경 OIDC 로그인
aws-oidc login prd   # prd 환경 OIDC 로그인
```
> `aws sso login` 직접 실행 금지

### 올바른 방식
```
파일 수정 → git commit → git push → ArgoCD 자동 동기화
```

### 시크릿 관리
- 평문 시크릿 커밋 금지
- AWS Secrets Manager + External Secrets 사용 (클러스터 시크릿)
- **로컬 토큰**: macOS Keychain + env var (`$SLACK_BOT_TOKEN`, `$ATLASSIAN_API_TOKEN` 등)
  - `op read` 직접 호출 금지, `/tmp/.*_token` 캐시 패턴 폐기
  - 글로벌 CLAUDE.md "시크릿 사용 (Keychain + env var)" 섹션 참조
- **⛔ 시크릿 평문 출력 절대 금지**: `.env`·1Password·키체인에서 값을 읽을 때 터미널/응답에 평문으로 출력하지 않는다. 키체인 저장 후 "저장 완료"만 출력. 확인 시 값 대신 존재 여부만 표시
- 상세: [docs/reference/secrets.md](../docs/reference/secrets.md)

---

## 📁 레포 구조

```
imports/     Terramate imports (backend, providers)
modules/     Terraform 모듈
stacks/      Terramate 스택 (실제 인프라)
argocd/      ArgoCD Application 정의
charts/      Helm 차트
values/      Helm values (환경별)
manifests/   K8s 매니페스트
docs/        상세 문서
```

---

## 🛠 Terramate 로컬 실행 (상태조작 전용)

> Terraform plan/apply/init/destroy는 **모두 CI/CD가 처리**. 로컬에서는 state 조작(state mv/import)만 허용.
> ⛔ **로컬 plan 금지** — 변경 영향은 PR의 CI plan 결과로 확인한다. (사용자 지시: "PR에서 알아서 CI 돌아갈텐데 왜 로컬에서 테스트함")

```bash
# 스택 목록 (조회만, OK)
terramate list --tags=prd

# state mv (CI/CD 불가 작업)
terramate run --tags=prd:pia-albc --enable-sharing --mock-on-fail -- \
  terraform state mv 'old.resource' 'new.resource'

# import (CI/CD 불가 작업)
terramate run --tags=prd:eks --enable-sharing --mock-on-fail -- \
  terraform import 'resource.addr' 'resource-id'
```

---

## 🚀 배포 워크플로우

### Terraform (인프라)
코드 수정 → `git push` → CI/CD (`deploy.yml`)가 자동으로 변경된 스택 plan + apply.

### ArgoCD (앱/매니페스트)
```
argocd/{env}/apps/    → Application 정의
values/{apps|infra}/  → Helm values
manifests/            → Raw manifests
```

> ⚠️ **manifests 경로 규칙**: `manifests/{app}/{env}/` (앱 먼저, 환경 나중)
> - ✅ `manifests/stockroom/prd/`
> - ❌ `manifests/prd/stockroom/`
Git push하면 ArgoCD가 자동 동기화

#### Push 후 싱크 확인 (필수)
ArgoCD 관련 파일(`argocd/`, `values/`, `manifests/`) push 시 **싱크 완료까지 확인**:
```bash
# 앱 상태 확인 (Synced + Healthy 될 때까지)
argocd app get <app-name> -o json | jq '{sync: .status.sync.status, health: .status.health.status}'

# 싱크가 안 되면 수동 트리거
argocd app sync <app-name>
```
- `Synced` + `Healthy` 확인 후 작업 완료 처리
- `OutOfSync` 또는 `Degraded` 시 원인 파악 후 대응

---

## 📦 Helm Chart 작업 규칙

### values 수정 시
- 수정 전 `values/`의 `_defaults.yaml` 파일을 먼저 참조할 것
- chart 버전은 ArgoCD Application manifest의 `targetRevision` 확인
- 기본값과 다른 설정에는 주석으로 이유 명시

### chart 버전 업그레이드 시
```bash
helm show values <repo>/<chart> > values/.../_defaults.yaml
```
`_defaults.yaml` 파일도 함께 갱신할 것

### 새 Helm chart 추가 시
1. `values/{apps|infra}/<chart>/` 디렉토리 생성
2. `_defaults.yaml` 생성 (helm show values 결과)
3. `dev.yaml`, `prd.yaml` 환경별 values 작성

```bash
# _defaults.yaml 생성 예시
helm show values kafka-ui/kafka-ui > values/infra/kafka-ui/_defaults.yaml
```

---

## 📐 Terramate 변수 구조

| 구분 | 용도 | 위치 | 예시 |
|------|------|------|------|
| **globals** | 환경별 원시 데이터 | config.tm.hcl | `environment`, `account_id`, `tags` |
| **locals** | globals 조합/계산값 | modules/*/locals.tm.hcl | `cluster_name = "${domain}-${env}"` |
| **variables** | 외부 모듈 설정값 (기본값) | modules/*/variables.tm.hcl | `github_repositories` |
| **tfvars** | 환경별 variable 오버라이드 | stacks/.../tfvars.tm.hcl | `coredns_replica_count = 3` |
| **input** | 스택 간 output 전달 | stack.tm.hcl | `vpc_id`, `subnet_ids` |

> ⚠️ 파일 저장 시 pre-commit hook이 자동 실행됨 (`.pre-commit-config.yaml` 참고)
>
> | Hook | 대상 파일 | 설명 |
> |------|-----------|------|
> | `terramate-generate` | `.hcl`, `.tf` | Terramate 코드 생성 |
> | `terramate-fmt` | `.hcl` | Terramate 포맷팅 |
> | `terraform-fmt` | `.tf` | Terraform 포맷팅 |
> | `tflint` | `.tf` | Terraform 린트 |
> | `terraform-docs` | `.tf` | terraform-docs 자동 생성 (`.terraform-docs.yml` 설정 사용) |

---

## 🔗 상세 문서

| 문서 | 내용 |
|-----|------|
| [Terramate 구조](../docs/reference/terramate-structure.md) | globals, locals, variables 가이드 |
| [새 앱 배포](../docs/runbooks/new-app.md) | ArgoCD Application 추가 |
| [시크릿 관리](../docs/reference/secrets.md) | External Secrets 사용법 |
| [네트워킹](../docs/reference/networking.md) | Traefik + ALB + ExternalDNS |
| [Helm 버전](../docs/reference/helm-versions.md) | 차트 버전 관리 정책 |

---

## ⚡ Quick Reference

### 환경
- `dev` - 개발 (AWS default profile)
- `prd` - 프로덕션 (AWS_PROFILE=prd)

### 사용자 선호
- kubectl context 확인/전환 시 `kubectx` 사용 (`kubectl config current-context` 대신)
- AWS SSO 토큰 만료 시 질문 없이 알아서 `aws-oidc login {env}` 실행
- **큰 작업은 worktree에서 진행**: 신규 앱/차트/스택 추가, 멀티파일 변경, PR이 필요한 작업 등은 `EnterWorktree`로 격리된 worktree에서 작업할 것. 단순 수정(단일 파일, hotfix)은 main에서 직접 가능
- **Terraform 작업은 무조건 worktree + PR**: Terraform/Terramate 관련 변경(스택 추가, 모듈 수정, tfvars 변경 등)은 규모와 관계없이 반드시 `EnterWorktree`로 worktree 생성 → 브랜치에서 작업 → PR 생성. main 직접 커밋 금지
- **PR 생성 시 자동 머지 설정**: `gh pr create` 직후 반드시 `gh pr merge {num} --auto --squash --delete-branch` 실행하여 CI 통과 시 자동 머지되도록 설정. 사용자 확인 대기 없이 진행 (긴급 장애 대응이나 사용자가 "머지하지 마" 명시 시는 예외)
- **PR auto-merge 설정 직후 로컬 정리 (머지 완료 대기 금지)**: `gh pr merge --auto` 호출 뒤 **즉시** 아래를 실행해서 찌꺼기를 안 남긴다. remote 머지는 비동기로 이뤄지지만 커밋은 PR 메타데이터에 보존되므로 로컬 참조를 지워도 안전하다.
  1. 메인 워크디렉토리로 복귀 (`git -C /Users/user/works/devops-configs checkout main`)
  2. `git worktree remove <path> --force` 로 해당 worktree 제거 (또는 `ExitWorktree(action=remove, discard_changes=true)`)
  3. `git branch -D <branch>` 로 로컬 브랜치 제거 (squash merge는 `-d`가 거부하므로 `-D`)
  4. 위 1–3은 `gh pr merge --auto` 성공 return 직후 같은 턴 안에서 수행. "CI 기다렸다가"라는 예외 없음

### K8s 클러스터 컨텍스트
> kubectl 실행 전 반드시 `kubectx`로 컨텍스트 확인 후 작업

| 컨텍스트 | 환경 | 상태 |
|----------|------|------|
| `acme-dev` | dev | 운영 중 |
| `acme-prd` | prd | 운영 중 |
| `orbit-dev` | ORBIT dev | 운영 중 |
| `orbit-prd` | ORBIT prd | 운영 중 |

- **현재 작업 대상**: `acme-dev`, `acme-prd`, `orbit-dev`, `orbit-prd`
- **작업 브랜치**: `main`

### Git 커밋 컨벤션

커밋 메시지는 Conventional Commits 형식을 따른다: `{type}({scope}): {description}`

| type | 용도 |
|------|------|
| `feat` | 새 앱/차트/스택 추가 |
| `fix` | 잘못된 설정, 버그 수정 |
| `chore` | 버전업, 문서, 정리 |
| `hotfix` | 긴급 장애 대응 |
| `refactor` | 동작 변경 없는 구조 개선 |

**언어**: description(제목)은 영어, 동사 원형으로 시작. body(본문)는 필요 시 한국어 허용.

scope는 변경 대상: `{app}`, `{app}/{env}`, `{infra-area}`
- 예: `feat(argo-workflows): add helm chart`, `fix(stockroom/prd): correct DB_HOST`, `hotfix(stockroom/prd): increase memory to resolve OOM`

**브랜치 사용 기준:**

| 변경 유형 | 브랜치 | PR |
|-----------|--------|-----|
| 단일 앱·단일 환경 소규모 수정 | `main` 직접 | 선택 |
| 신규 앱/차트/스택 추가 | `feat/{scope}/{desc}` | 필수 |
| Terraform 인프라 변경 | `feat/*` 또는 `chore/*` | 필수 + plan 결과 첨부 |
| 긴급 장애 대응 | `main` 직접 | 사후 이슈 생성 |

**커밋 품질**: 혼자 작업하더라도 커밋 메시지에 why(이유)를 남긴다. values 파일에서 기본값과 다른 설정에는 주석으로 이유를 명시한다.

### 스택
```
tfstate, oidc, vpc, eks, addons, argocd-helm, karpenter-helm,
argocd, karpenter, pia-{albc,ebs,extdns,extsec,aiu,mall,venue,web,all},
iam-loki, iam-authentik, iam-authentik-saml, iam-authentik-oidc,
ecr-stockroom
```

### 자주 쓰는 명령
```bash
# Terraform (확인용 plan만 로컬 실행, apply/init는 CI/CD 자동)
terramate run --tags=prd --changed --parallel 5 --enable-sharing --mock-on-fail -- terraform plan

# kubectl (읽기만)
kubectl get pods -n <ns>
kubectl logs -f <pod>

# ArgoCD
argocd app list
argocd app sync <app>
```

### GitHub Actions / CI 패턴
- IAM 역할명: `GitHubActions` (unfunco/oidc-github/aws 기본값)
- AWS named profile 필수: backend `profile = "dev/prd"` 사용하므로 OIDC env var → named profile 변환 필요
- `GITHUB_TOKEN`은 반드시 **job-level** env (step-level은 Terramate wrapper가 못 읽음)
- Terramate Cloud GitHub Trust: Settings → General → GitHub Trust에서 repo/org 등록 필요
- Terramate Cloud org: `acme-devops` (terramate.tm.hcl)
- stack tags: `dev`, `prd` (v2 suffix 없음)
### git worktree 주의사항
- worktree 세션에서 bash cwd가 worktree로 리셋됨 — 메인 레포 작업 시 `cd /절대경로` 필요
- worktree 브랜치 push 시 tracking 확인: `git push origin local-branch:remote-branch`
- **PR 머지 후 반드시 `ExitWorktree(action=remove)`로 워크트리 정리** — 머지된 커밋은 main에 보존되므로 `discard_changes: true` 사용 가능
- **auto-merge 설정과 로컬 정리는 같은 턴에 수행** — `gh pr merge --auto` 직후 worktree/브랜치 삭제까지 한 세트로. CI 통과를 기다리지 않는다(세션이 먼저 끝나면 영영 안 치움 → 찌꺼기 누적 원인)

---

## 🎯 Multi-Source Application 참고

### mall-v4-batch (배치 작업)

**Application 정의**: `argocd/{env}/apps/mall/v4-batch.yaml`

**구조** (Multi-Source):
| 소스 | 레포 | 브랜치 | 용도 |
|------|------|--------|------|
| backendRepo | acmemall-backend-v4 | dev/main | Job 정의 (`mall/batch/helm/{env}.yaml`) |
| values | devops-configs | `mall/v4/batch` | 공통 values (`manifest/mall/v4/batch/values/`) |
| chart | devops-configs | `mall/v4/batch` | Batch Helm 차트 (`charts/batch/`) |

**수정 시 주의**:
- Job 정의 (app 섹션): Backend 레포에서 수정
- 공통 설정 (commonValues): devops-configs `mall/v4/batch` 브랜치
- Chart 템플릿: devops-configs `mall/v4/batch` 브랜치

**브랜치 분리 이유**: GitHub Actions에서 이미지 태그 변경 시 자동 커밋이 발생하는데, main에 섞이면 git 트리가 지저분해져서 별도 브랜치로 분리 (chart + values만 존재)

---

## 📌 운영 노하우 (Lessons Learned)

### Argo Workflows SSO (v3.7) 설정 패턴
- **RBAC 필수 설정** (K8s 1.24+): `rbac.enabled: true` + SA + ClusterRoleBinding + **token Secret 수동 생성**
  - Secret type: `kubernetes.io/service-account-token`, annotation: `kubernetes.io/service-account.name`
  - 없으면 `code:7 "not allowed"` 발생
- **rbac-rule**: `"true"` (모든 SSO 사용자 매칭), `rbac-rule-precedence: "1"`
- **`/api/v1/info`**: v3.7에서 인증 없이 항상 `code:16` 반환 → 초기 페이지 로드 시 정상 (로그인 전)
- **SSO 자동 리다이렉트**: Traefik Middleware(redirectRegex) + HeaderRegexp(Cookie) 조합으로 구현
  - Route 1 (priority 20): `HeaderRegexp('Cookie', 'authorization=')` → argo-workflows 직접 전달
  - Route 2 (priority 15): `Path('/')` → redirectRegex로 `/oauth2/redirect?redirect=/` 리다이렉트
  - Route 3 (priority 10): 나머지 경로 → argo-workflows 직접 전달
  - SSO 콜백 후 `authorization` 쿠키(HttpOnly) 설정됨 → Route 1 매칭 → 무한루프 없음

### Traefik v3 문법 변경 주의
- `HeadersRegexp` (v2) → `HeaderRegexp` (v3 단수형): v3에서 v2 문법 사용 시 라우트 생성 안 됨
- IngressRoute에서 `HeadersRegexp` 사용 시 Traefik v3가 라우트를 무시 → fallback 라우트만 매칭
- v2→v3 업그레이드 시 모든 IngressRoute 룰 문법 검토 필요

### Authentik 리소스 관리
- server CPU 500m 한도 → throttle 발생 → readiness probe timeout → 재시작 → 503
- prd 적정 한도: server cpu 1000m / memory 2Gi, worker cpu 500m / memory 1Gi

---

## 🧠 작업 방식 (Workflow Orchestration)

### 1. Plan First
- 3단계 이상이거나 아키텍처 결정이 필요한 작업은 **plan mode 진입**
- 작업 중 방향이 틀어지면 즉시 멈추고 **재계획** — 밀어붙이지 않는다
- 계획에 검증 단계도 포함할 것 (빌드만이 아니라 확인까지)

### 2. Subagent 활용
- 메인 컨텍스트를 깨끗하게 유지하기 위해 서브에이전트 적극 활용
- 리서치, 코드 탐색, 병렬 분석은 서브에이전트에 위임
- 복잡한 문제에는 서브에이전트를 여러 개 병렬 투입
- 서브에이전트 하나에 하나의 목적만 부여

### 3. 자기 개선 루프
- 사용자로부터 수정 지시를 받으면: **memory 파일에 패턴 기록**
- 같은 실수를 반복하지 않도록 규칙을 작성
- 세션 시작 시 memory 파일 리뷰

### 4. 검증 후 완료
- 작업 완료 표시 전에 **동작 확인 필수**
- Terraform: `plan` 결과 확인, ArgoCD: `Synced + Healthy` 확인
- 스스로 자문: "시니어 엔지니어가 이걸 승인하겠는가?"
- 로그, 에러, 상태를 직접 확인하고 정상임을 증명

### 4-1. ⛔ 앱 코드 — 머지 전 로컬 테스트 필수
**클라우드 환경(K8s rollout / ArgoCD) 으로 검증 대체 금지. 너무 느림.**
- `compile / test / lint` 통과만으로 부족
- **반드시 `./gradlew bootRun` (Spring) / `go run` 등 로컬 기동 후 신규·수정 endpoint curl 검증**
- Bean 조건 (`@ConditionalOnExpression` / `@ConditionalOnProperty`) / DataSource / spring.config.import 변경 시 특히 주의 — startup log 에서 `APPLICATION FAILED TO START` 없어야
- DB/외부 의존성으로 bootRun 어려우면 **사용자 확인 받고 결정**
- PR 본문에 "로컬 검증 완료" 또는 "로컬 검증 불가 — 사용자 확인" 명시
- 서브에이전트 위임 시 위 룰 프롬프트에 **반드시 명시**

### 5. 우아함 추구 (균형 있게)
- 단순한 수정은 그대로 진행. **과도한 엔지니어링 금지**
- 비자명한 변경에서만: "더 깔끔한 방법이 있는가?" 자문
- 임시방편(hacky fix)이 느껴지면 근본 원인부터 해결
- 제출 전 자기 작업을 한 번 더 검토

### 6. 자율 버그 수정
- 버그 리포트를 받으면: 질문 없이 바로 수정에 착수
- 로그, 에러, 실패 테스트를 먼저 확인하고 해결
- 사용자의 컨텍스트 스위칭을 최소화
- CI 실패도 지시 없이 자율적으로 수정 시도

### 핵심 원칙
- **단순함 우선**: 변경은 최대한 단순하게. 영향 범위 최소화
- **근본 원인 해결**: 임시 수정 금지. 시니어 개발자 기준으로 작업
- **최소 영향**: 필요한 부분만 변경. 부수적 버그 유입 방지

---

## 📢 작업 완료 시 Slack 자동 알림

의미 있는 작업이 완료되면 `/slack` 스킬을 **자동으로 실행**한다. 사용자가 별도로 요청하지 않아도 된다.

**알림 대상 (자동 전송):**
- 인프라 변경 (Terraform apply, Karpenter NodePool 변경 등)
- 앱/서비스 배포 또는 설정 변경
- AWS 리소스 생성/삭제/변경
- 장애 대응 완료

**알림 제외 (전송하지 않음):**
- 단순 조회/확인 작업 (kubectl get, aws describe 등)
- 문서만 수정
- 커밋/푸시 없는 코드 리뷰
- 사용자가 "슬랙 보내지 마" 등으로 명시적 거부

---

## 📝 세션 기록

컨텍스트 compaction 시 `~/.claude/sessions/devops-configs/`에 마크다운으로 기록

**파일명**: `{YYYY-MM-DD}-{작업주제}.md`

**형식**:
```markdown
# {작업 주제}

**날짜**: YYYY-MM-DD
**레포**: devops-configs

## 요약
- 한 줄 요약

## 주요 결정/변경
- 왜 이렇게 했는지 (git에서 안 보이는 맥락)

## TIL
- 배운 점, 삽질, 다음에 참고할 내용

## 관련 커밋
- `hash` message
```
