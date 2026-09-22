# DevOps Configs

Acme의 인프라 및 애플리케이션 배포를 위한 IaC(Infrastructure as Code) 및 DevOps 구성 파일을 관리하는 저장소입니다.

**주요 기술 스택**: Terramate, Terraform, Helm, ArgoCD, Kubernetes

---

## 📋 목차

- [브랜치 정책](#브랜치-정책)
- [개발 환경 설정](#개발-환경-설정)
- [디렉터리 구조](#디렉터리-구조)
- [사용 방법](#사용-방법)
- [기여 가이드](#기여-가이드)

---

## 🌟 브랜치 정책

- **현재 메인 브랜치**: `main`


---

## ⚙️ 개발 환경 설정

### 필수 도구 버전

`.tool-versions` 파일(asdf) 기준으로 관리됩니다:

| 도구 | 버전 | 참고 |
|------|------|------|
| terramate | 0.14.7 | [asdf-terramate](https://github.com/martinlindner/asdf-terramate) |
| terraform | 1.13.5 | |
| opentofu | 1.9.0 | |
| terraform-docs | 0.20.0 | |
| tflint | 0.60.0 | |

### asdf 설치 (macOS + zsh)

```bash
# 1. asdf 설치
brew install asdf

# 2. zsh 환경 설정
echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ${ZDOTDIR:-~}/.zshrc
source ~/.zshrc

# 3. 프로젝트 도구 설치
asdf install
```

> 💡 **상세 설치 가이드**: [docs/runbooks/install_asdf.md](docs/runbooks/install_asdf.md)

---

## 📁 디렉터리 구조

```
📦 devops-configs
├── imports/                   # 공통 import HCL
├── modules/                   # Terramate/Terraform 모듈
├── stacks/                    # v2 Terramate 스택
├── argocd/                    # ArgoCD Application/Project
├── charts/                    # Helm 차트
├── values/                    # Helm values (apps/infra)
├── manifests/                 # Raw manifests (app/env)
├── apps/                      # 애플리케이션 소스/설정
├── test/                      # 테스트/검증 리소스
├── scripts/                   # 운영 스크립트 (aws-oidc 등)
├── docs/                      # 문서 (reference, runbooks, logs 등)
├── _bootstrap/                   # 초기 부트스트랩 스택
└── Makefile                      # Terraform/Terramate 실행 진입점
```

### 주요 디렉터리 설명

| 디렉터리 | 용도 |
|----------|------|
| `modules/` | Terramate/Terraform 공통 모듈 |
| `stacks/` | v2 스택(dev/prd) 구성 |
| `argocd/` | ArgoCD Application/Project 정의 |
| `values/` | Helm values (`apps/`, `infra/`) |
| `manifests/` | Raw Kubernetes manifests (`{app}/{env}`) |

---

## 🚀 사용 방법

### 1️⃣ Terramate/Terraform (인프라 배포)

> **✅ 자동 배포**: 코드 수정 → `git push` → CI/CD(`deploy.yml`)가 자동으로 plan + apply합니다.

#### AWS 인증(OIDC)
```bash
# 최초 1회: ~/.aws/config에 credential_process 등록
make aws-setup-config

# 로그인
make aws-login-dev
make aws-login-prd

# 현재 인증 확인
make aws-whoami
```

---

### 2️⃣ Helm 차트 & Kubernetes 매니페스트 (자동 배포)

> **✅ 자동 배포**: Git push만으로 ArgoCD가 자동 감지하여 배포

#### 배포 프로세스
1. 코드 수정
2. `git push` (GitHub Flow)
3. ArgoCD 자동 sync
4. 배포 완료

#### 지원 리소스
- Helm 차트 (`charts/`, `values/`)
- Kubernetes 매니페스트 (`manifests/`)
- ArgoCD 애플리케이션 (`argocd/`)

---

### 3️⃣ ArgoCD 애플리케이션 관리

`argocd/` 디렉터리의 매니페스트를 통해 애플리케이션을 관리합니다.

- **Application**: `argocd/{env}/{apps|infra}/`
- **Project**: `argocd/{env}/proj/`
- **Helm values**: `values/{apps|infra}/`
- **Raw manifests**: `manifests/{app}/{env}/`

> 🚨 **ArgoCD 브랜치 정책**
> - 모든 Application의 `targetRevision`은 **`main`** 브랜치 사용을 원칙으로 합니다.
> - 예외적인 브랜치 사용은 사전 승인 및 문서화가 필요합니다.
> - 상세 정책 및 예외 목록은 [ArgoCD 브랜치 정책](docs/reference/BRANCH_REVISION_POLICY.md)을 참고하세요.

---

## � 문서 구조 (`docs/`)

문서는 목적에 따라 다음 구조로 관리됩니다:

- **`reference/`**: 정책, 아키텍처, 가이드 등 Single Source of Truth (예: 네이밍 가이드, 인증 표준)
- **`runbooks/`**: 운영 절차, 트러블슈팅, 수동 작업 내역 등 How-to 문서
- **`incidents/`**: 장애 보고서 및 포스트모템
- **`logs/`**: 작업 이력 (daily, weekly, session logs) - 검색용 아카이브이며 운영 기준으로 사용하지 않음
- **`archive/`**: Deprecated 문서 및 과거 이력

> 💡 **주요 문서 링크**
> - [문서 작성 가이드](docs/reference/DOCUMENTATION_GUIDE.md)
> - [네이밍 가이드](docs/reference/NAMING_GUIDE.md)
> - [AWS CLI OIDC 인증](docs/reference/aws-cli-oidc.md)
> - [수동 작업 내역](docs/runbooks/manual-tasks.md)

---

## �🛠️ 추가 도구 설정

### VSCode Pre-commit 자동 실행

파일 저장 시 자동으로 코드 품질 검사를 실행합니다.

#### 1. 확장 프로그램 설치
[Run on Save](https://marketplace.visualstudio.com/items?itemName=emeraldwalk.RunOnSave)

#### 2. settings.json 설정
```jsonc
"emeraldwalk.runonsave": {
  "commands": [
    {
      "match": ".*",
      "cmd": "pre-commit run --all-files",
      "isAsync": true
    }
  ]
}
```
---

## 📝 수동 작업 내역

- Terraform으로 자동화되지 않은 리소스 변경 사항은 [docs/runbooks/manual-tasks.md](docs/runbooks/manual-tasks.md) 문서에 기록합니다.
- 예: AWS 콘솔에서 직접 변경한 보안 그룹 인바운드 규칙 등

---

### 의존성 도구
- [Terramate](https://terramate.io/)
- [Terraform](https://www.terraform.io/)
- [Helm](https://helm.sh/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

---

## 🤝 기여 가이드

### 기본 원칙
1. **이슈 등록** 또는 **PR 생성**
2. **코드 스타일** 및 **커밋 메시지 가이드** 준수
3. **민감 정보 절대 커밋 금지**
4. **모든 작업은 `main` 브랜치 기준**

### Git 정책
- **GitHub Flow** 준수
- **PR 리뷰** 필수
- **브랜치 전략**: feature → `main`

---

## 📄 라이선스

이 저장소의 라이선스는 **Acme 내부 정책**을 따릅니다.
