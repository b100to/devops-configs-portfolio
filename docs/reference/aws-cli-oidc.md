# AWS CLI/LLM OIDC 인증 (authentik)

SAML(`saml2aws`) 대비 장점:
- 최초 1회 브라우저 로그인 → refresh token으로 **12시간 자동갱신**
- `credential_process` 연동으로 CLI/LLM 완전 투명
- PKCE 기반 public client (client_secret 불필요)

## 아키텍처

```
┌──────────┐   Authorization Code + PKCE   ┌────────────────┐
│ aws-oidc │ ─────────────────────────────→ │ authentik       │
│   .sh    │ ←── id_token + refresh_token ──│ (sso.acme.example) │
└──────────┘                                └────────────────┘
     │
     │ AssumeRoleWithWebIdentity(id_token)
     ▼
┌──────────┐   STS 임시자격증명
│ AWS STS  │ ─────────────────→ credential_process JSON
└──────────┘
```

## 전제

- authentik에 `aws-cli` OIDC Provider가 설정됨 (Blueprint으로 관리)
- AWS에 IAM OIDC Identity Provider가 등록됨 (Terraform으로 관리)
- 사용자가 authentik `devops-admin` 또는 `developer` 그룹에 속해야 함

## 그룹별 권한 매핑

| authentik 그룹 | dev 환경 | prd 환경 |
|---------------|----------|----------|
| `devops-admin` | AdministratorAccess | AdministratorAccess |
| `developer` | PowerUserAccess | ReadOnlyAccess |

IAM Role 이름:
- `authentik-oidc-admin` (devops-admin 그룹)
- `authentik-oidc-developer` (developer 그룹)

## 요구사항

- `python3` (토큰 파싱, 로컬 콜백 서버)
- `openssl` (PKCE 생성)
- `curl` (토큰 교환)
- `aws` CLI

## 설정

### 1) AWS config에 credential_process 등록

```bash
# config snippet 자동 생성
scripts/aws-oidc.sh config-snippet >> ~/.aws/config

# 또는 별도 config 파일 사용
export AWS_CONFIG_FILE=$HOME/.config/aws/config
scripts/aws-oidc.sh config-snippet >> "$AWS_CONFIG_FILE"
```

생성되는 설정:
```ini
[profile dev-oidc]
region = ap-northeast-2
credential_process = /path/to/devops-configs/scripts/aws-oidc.sh credential-process dev

[profile prd-oidc]
region = ap-northeast-2
credential_process = /path/to/devops-configs/scripts/aws-oidc.sh credential-process prd
```

### 2) 사용

```bash
# 최초 1회: 브라우저 열림 → Google SSO → authentik → 토큰 캐시
aws --profile dev-oidc sts get-caller-identity

# 이후: refresh token으로 자동갱신 (브라우저 안 열림)
aws --profile dev-oidc s3 ls

# prd
aws --profile prd-oidc sts get-caller-identity
```

### 3) 역할 명시적 지정 (선택)

```bash
# 기본: id_token의 groups claim에서 자동 감지
# devops-admin 그룹 → admin role, developer 그룹 → developer role

# 명시적 지정
scripts/aws-oidc.sh --role admin credential-process dev
scripts/aws-oidc.sh --role developer credential-process prd
```

## 명령어 참조

```bash
# 브라우저 로그인 (토큰 캐시)
scripts/aws-oidc.sh login dev
scripts/aws-oidc.sh login prd

# credential_process (AWS CLI 자동 호출)
scripts/aws-oidc.sh credential-process dev

# 현재 토큰 확인
scripts/aws-oidc.sh whoami

# AWS config snippet 출력
scripts/aws-oidc.sh config-snippet
```

## 토큰 캐시 구조

```
~/.cache/aws-oidc/
├── id_token         # OIDC id_token (JWT)
├── refresh_token    # OIDC refresh_token (12h 유효)
├── sts_dev.json     # STS 임시자격증명 캐시 (1h 유효)
└── sts_prd.json
```

토큰 갱신 순서:
1. STS 캐시가 유효하면 즉시 반환
2. STS 만료 → id_token 유효하면 새 STS 발급
3. id_token 만료 → refresh_token으로 갱신
4. refresh_token 만료 → 브라우저 로그인

## 인프라 관리 (Terraform)

코드 수정 → `git push` → CI/CD가 자동으로 plan + apply.

```bash
# 로컬에서 plan 확인 (선택)
terramate run --tags=dev:iam:authentik:oidc --enable-sharing --mock-on-fail -- terraform plan
terramate run --tags=prd:iam:authentik:oidc --enable-sharing --mock-on-fail -- terraform plan
```

## SAML(기존)과의 공존

| | SAML (saml2aws) | OIDC (aws-oidc.sh) |
|---|---|---|
| 용도 | AWS 콘솔 로그인 | CLI/LLM |
| 프로필 | `dev` / `prd` | `dev-oidc` / `prd-oidc` |
| 갱신 | 매번 브라우저 | refresh token 12h |
| 스크립트 | `scripts/aws-auth.sh` | `scripts/aws-oidc.sh` |
| IAM Role | `authentik-admin` | `authentik-oidc-admin` / `authentik-oidc-developer` |

## authentik 그룹 관리

Blueprint(`manifests/authentik/prd/blueprints.yaml`)에서 그룹 생성:
- `devops-admin`: DevOps 팀 (AdministratorAccess)
- `developer`: 개발자 (환경별 차등 권한)

사용자를 그룹에 추가하려면:
1. authentik Admin > Directory > Users > 해당 유저
2. Groups 탭에서 `devops-admin` 또는 `developer` 추가

## 트러블슈팅

- **`AssumeRoleWithWebIdentity failed`**: IAM OIDC Identity Provider가 등록되었는지 확인
  ```bash
  aws iam list-open-id-connect-providers --profile dev
  ```
- **`groups claim missing`**: authentik의 aws-cli provider에 groups scope mapping이 연결되었는지 확인
- **`refresh token expired`**: 12시간 초과 시 `aws-oidc.sh login dev`로 재로그인
- **포트 충돌**: `--port` 옵션으로 다른 포트 지정
  ```bash
  scripts/aws-oidc.sh --port 18401 login dev
  ```
