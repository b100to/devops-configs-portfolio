# Follow-ups: AWS CLI Auth (authentik SAML + saml2aws)

> **⚠️ DEPRECATED**: 현재 인증 표준은 OIDC 기반(`aws-cli-oidc.md`)으로 통일되었습니다. 이 문서는 과거 이력 보존용으로만 남겨둡니다.

Context
- Goal: no long-lived access keys (`~/.aws/credentials` not used), local human auth via authentik SAML, automation via separate non-interactive path.
- Current local approach: `saml2aws` with cache file `~/.cache/saml2aws/aws-credentials`.
- Helper scripts:
  - `scripts/aws-saml2aws.zsh`
  - `scripts/aws-saml2aws-credential-process.sh` (AWS CLI `credential_process`)

Open items
- Decide the default local integration:
  - Option A: wrapper functions (`awsdev`, `awsprd`, `saml_env_dev`, `saml_env_prd`)
  - Option B: AWS CLI `credential_process` with `AWS_CONFIG_FILE` on WSL Linux FS
- WSL file placement hardening:
  - Avoid `/mnt/c` for credential cache/config where possible.
  - Document expected paths and the rationale (ACL vs chmod semantics).
- Clean up scripts:
  - There is also `scripts/aws-credential-process.sh` (untracked). Confirm whether it is obsolete and remove/replace it to avoid confusion.
- Security wording in docs:
  - Avoid absolute claims like "memory-only" or "탈취 시 재사용 불가"; keep statements precise.
- CI/CD non-interactive path design:
  - Add an OIDC-based role assumption path (e.g., GitHub Actions `AssumeRoleWithWebIdentity`) and document it separately from SAML.
- Optional: reduce friction for browser login
  - Evaluate whether `saml2aws` Browser provider can reuse an existing local Chrome profile (cookie reuse) safely, or keep current default.

Acceptance criteria (later)
- Local: `aws --profile dev sts get-caller-identity` works via `credential_process` without touching `~/.aws/credentials`.
- Local: switching `dev` <-> `prd` is one command and does not leak credentials into process listings.
- CI: pipeline gets AWS creds via OIDC, not via SAML, and has least-privilege roles.

