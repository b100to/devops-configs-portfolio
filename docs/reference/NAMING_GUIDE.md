# 네이밍 가이드

이 문서는 Acme DevOps 인프라 저장소에서 사용하는 네이밍 규칙과 조직 구조를 설명합니다.

## 목차

- [디렉토리 구조](#디렉토리-구조)
- [네이밍 규칙](#네이밍-규칙)
- [파일 네이밍](#파일-네이밍)
- [예제](#예제)
- [베스트 프랙티스](#베스트-프랙티스)

---

## 디렉토리 구조

### 루트 레벨 넘버링

모든 루트 레벨 디렉토리는 실행 순서와 논리적 그룹핑을 나타내는 두 자리 숫자 접두사를 사용합니다:

```
00-09: 향후 사용을 위해 예약
imports/         # 공유 import (backend, providers, data sources)
modules/         # 재사용 가능한 Terraform 모듈
stacks/          # Terraform/Terramate 인프라 스택
argocd/          # ArgoCD 애플리케이션 정의
charts/          # Helm 차트
values/          # Helm values 파일
manifests/       # Kubernetes manifest 파일
apps/            # 애플리케이션 설정
test/            # 테스트 유틸리티
scripts/         # 자동화 스크립트
image/           # 컨테이너 이미지 및 Dockerfile
docs/            # 문서 (참조 자료는 마지막에)
```

**규칙:**
- 두 자리 접두사 사용 (00-99)
- 낮은 숫자 = 배포 파이프라인에서 먼저 실행
- 99는 문서용으로 예약
- 단어는 언더스코어로 구분 (snake_case)

### 스택 디렉토리 구조

`stacks/` 내부는 다음 계층 구조를 따릅니다:

```
stacks/
└── {조직명}/                    # 예: acme
    ├── vpc/                  # VPC 및 네트워킹 (기반)
    ├── eks/                  # EKS 클러스터
    ├── add_ons/              # EKS 애드온
    ├── helm/                 # Helm 릴리스
    ├── manifests/            # Raw Kubernetes manifests
    ├── pod-identity-agent/   # Pod identity 설정
    ├── iam/                  # IAM 역할 및 정책
    └── 07_msk/                  # MSK (Kafka) 클러스터
```

**순서 규칙:**
1. 인프라 의존성이 먼저 (VPC가 EKS보다 먼저)
2. 낮은 숫자 = 높은 숫자의 의존성
3. 두 자리 접두사 사용 (00-99)
4. snake_case 사용, 여러 단어로 된 리소스명에만 하이픈 사용

### 버전 및 환경 구조

```
stacks/acme/{리소스}/
├── main/                        # 현재 프로덕션 버전
│   ├── dev/                     # 개발 환경
│   │   ├── stack.tm.hcl
│   │   ├── config.tm.hcl
│   │   └── README.md
│   └── prd/                     # 프로덕션 환경
│       ├── stack.tm.hcl
│       ├── config.tm.hcl
│       └── README.md
└── v2/                          # 다음 버전 (예: EKS 업그레이드)
    ├── dev/
    └── prd/
```

**버전 네이밍:**
- `main`: 현재 프로덕션 안정 버전
- `v2`, `v3` 등: 메이저 버전 업그레이드 또는 Breaking Changes
- Git 태그는 시맨틱 버저닝 사용: `v1.0.0`, `v1.1.0` 등

**환경 네이밍:**
- `dev`: 개발 환경
- `prd`: 프로덕션 환경
- 일관성을 위해 3글자 약어 사용

---

## 네이밍 규칙

### 스택 이름 및 ID

**형식:** `{조직명}_{리소스}_{버전}_{환경}`

**예제:**
```hcl
stack {
  name = "acme_vpc_main_dev"
  id   = "acme_vpc_main_dev"
  tags = ["stack", "acme", "vpc", "dev"]
}

stack {
  name = "acme_eks_v2_prd"
  id   = "acme_eks_v2_prd"
  tags = ["stack", "acme", "eks", "v2", "prd"]
}
```

**규칙:**
- snake_case 사용 (모두 소문자, 언더스코어로 구분)
- 스택 `name`과 `id`는 동일해야 함
- Tags는 개별 구성요소의 배열
- 순서: 조직명 → 리소스 → 버전 → 환경

### 리소스 네이밍

**클러스터 이름:**
```
acme-main-dev        # 개발 클러스터 (main 버전)
acme-main-prd        # 프로덕션 클러스터 (main 버전)
acme-v2-dev          # 개발 클러스터 (v2 버전)
acme-v2-prd          # 프로덕션 클러스터 (v2 버전)
```

**규칙:**
- kebab-case 사용 (소문자, 하이픈으로 구분)
- 형식: `{조직명}-{버전}-{환경}`
- 짧지만 설명적인 이름 유지

### 모듈 이름

`modules/`의 모듈은 소문자와 언더스코어를 사용합니다:

```
modules/
├── add_ons/
├── eks/
├── helm/
├── iam/
├── manifests/
├── msk/
├── oidc_aws_github/
├── pod-identity-agent/
├── tfstate/
└── vpc/
```

**규칙:**
- 여러 단어는 snake_case 사용
- 복합 기술 용어는 하이픈 사용 (예: `pod-identity-agent`)
- 가능한 경우 AWS 서비스 이름과 일치시키기

---

## 파일 네이밍

### Terramate 파일

```
config.tm.hcl        # 스택 설정 (globals, variables)
stack.tm.hcl         # 스택 정의 (name, id, tags, dependencies)
imports.tm.hcl       # 공유 설정 import
```

**규칙:**
- 모든 Terramate 파일은 `.tm.hcl`로 끝남
- 목적을 나타내는 설명적인 이름 사용
- `stack.tm.hcl`은 최종 환경 레벨에 배치 (dev/prd)
- `config.tm.hcl`은 버전 레벨 또는 환경 레벨에 배치

### 생성 파일

Terramate가 자동으로 `_terramate_generated_` 접두사로 Terraform 파일을 생성합니다:

```
_terramate_generated_backend.tf
_terramate_generated_locals.tf
_terramate_generated_main.tf
_terramate_generated_outputs.tf
_terramate_generated_providers.tf
_terramate_generated_sharing_backend.tf
```

**규칙:**
- 절대 생성된 파일을 수동으로 편집하지 말 것
- 접두사: `_terramate_generated_`
- 확장자: `.tf`
- 일부 설정에서는 gitignore되지만 이 저장소에서는 커밋됨

### 문서 파일

```
README.md            # terraform-docs로 자동 생성
NAMING_GUIDE.md      # 이 파일
DOCUMENTATION_GUIDE.md
```

**규칙:**
- 가이드 문서는 UPPER_CASE 사용
- 모듈 자동 생성 문서는 README.md 사용
- Markdown 형식 (.md)

---

## 예제

### 새 스택 생성

새로운 인프라 구성요소를 추가할 때:

1. **순서 번호 결정:**
   ```
   vpc → eks → add_ons → [08_new_resource]
   ```

2. **디렉토리 구조 생성:**
   ```
   stacks/acme/08_new_resource/
   └── main/
       ├── dev/
       │   ├── stack.tm.hcl
       │   ├── config.tm.hcl
       │   └── main.tf (선택사항, imports를 사용하지 않을 경우)
       └── prd/
           ├── stack.tm.hcl
           ├── config.tm.hcl
           └── main.tf
   ```

3. **`stack.tm.hcl`에 스택 정의:**
   ```hcl
   stack {
     name = "acme_new_resource_main_dev"
     id   = "acme_new_resource_main_dev"
     tags = ["stack", "acme", "new_resource", "dev"]

     after = [
       "tag:dev:eks"  # EKS 의존성
     ]
   }
   ```

4. **terraform-docs 실행:**
   ```bash
   cd stacks/acme/08_new_resource/main/dev
   terraform-docs -c $(git rev-parse --show-toplevel)/.terraform-docs.yml .
   ```

### 새 버전 생성

인프라 업그레이드 시 (예: EKS 버전):

1. **main과 나란히 v2 디렉토리 생성:**
   ```
   stacks/acme/eks/
   ├── main/         # EKS 1.32
   └── v2/           # EKS 1.34
   ```

2. **스택 네이밍 업데이트:**
   ```hcl
   # v2/prd/stack.tm.hcl
   stack {
     name = "acme_eks_v2_prd"
     id   = "acme_eks_v2_prd"
     tags = ["stack", "acme", "eks", "v2", "prd"]
   }
   ```

3. **리소스 이름 업데이트:**
   ```hcl
   # v2/prd/config.tm.hcl
   globals {
     cluster_name = "acme-v2-prd"  # main과 다르게
   }
   ```

4. **dev에서 먼저 테스트, 그 다음 prd로 승격**

5. **성공적인 마이그레이션 후, main 디렉토리 제거**

---

## 베스트 프랙티스

### 일반 가이드라인

1. **일관성 유지:** 기존 패턴을 정확히 따르기
2. **의미 있는 이름 사용:** 이름은 구현이 아닌 목적을 설명해야 함
3. **단순하게 유지:** 명확하다면 짧은 이름이 더 좋음
4. **의존성 따르기:** 낮은 숫자는 의존성 없음, 높은 숫자는 낮은 숫자에 의존
5. **변경사항 문서화:** 새로운 패턴 도입 시 이 가이드 업데이트

### 해야 할 것과 하지 말아야 할 것

✅ **해야 할 것:**
- 순서를 위한 숫자 접두사 사용 (00_, 01_, 02_)
- 스택 이름과 ID에 snake_case 사용
- 리소스 이름(클러스터 등)에 kebab-case 사용
- 환경 이름은 짧게 유지 (dev, prd)
- 스택 생성 후 terraform-docs 실행
- prd 배포 전에 dev에서 테스트

❌ **하지 말아야 할 것:**
- 네이밍 규칙 혼용 (snake_case vs kebab-case)
- 숫자 접두사 생략
- 한 글자 약어 사용
- 문서 없이 스택 생성
- 생성된 파일 수동 편집
- dev 테스트 없이 prd 배포

### 버전 관리

**새 버전 디렉토리(v2, v3)를 생성해야 할 때:**
- 메이저 버전 업그레이드 (예: EKS 1.32 → 1.34)
- Blue-Green 배포가 필요한 Breaking Changes
- 호환되지 않는 인프라 변경

**제자리에서 업데이트해야 할 때(main):**
- 마이너 버전 패치
- 설정 업데이트
- Breaking 하지 않은 변경
- 애드온 업데이트

### 의존성 순서

새 스택 생성 시 다음 일반 의존성 순서를 따르세요:

1. **vpc**: 네트워크 기반
2. **eks**: Kubernetes 클러스터
3. **add_ons**: EKS 애드온 (클러스터 필요)
4. **helm**: Helm 애플리케이션 (클러스터 + 애드온 필요)
5. **manifests**: Raw Kubernetes 리소스
6. **pod-identity-agent**: Pod identity (클러스터 필요)
7. **iam**: IAM 역할 및 정책
8. **07_msk**: Kafka 클러스터 (네트워크 필요)

### Git 워크플로우

1. **브랜치 네이밍:** `feature/eks-v2`, `fix/vpc-routes` 등
2. **커밋 메시지:** Conventional commits 따르기
3. **태깅:** 시맨틱 버저닝 사용 (v1.0.0, v1.1.0, v1.2.0)
4. **PR 제목:** 변경사항의 명확한 설명

### Pre-commit Hooks

저장소는 자동화된 훅을 사용합니다:
- `terramate-generate`: Terraform 파일 자동 생성
- `terramate-fmt`: .hcl 파일 포맷팅
- `terraform-fmt`: .tf 파일 포맷팅
- `tflint`: Terraform 코드 린팅
- `terraform-docs`: README.md 자동 생성

커밋 전에 항상 실행하세요:
```bash
pre-commit run --all-files
```

---

## 빠른 참조

| 컨텍스트 | 형식 | 예제 |
|---------|------|------|
| 루트 디렉토리 | `NN_name/` | `stacks/` |
| 스택 디렉토리 | `NN_resource/` | `eks/` |
| 스택 이름/ID | `org_resource_version_env` | `acme_eks_v2_prd` |
| 클러스터 이름 | `org-version-env` | `acme-v2-prd` |
| 버전 | `main`, `v2`, `v3` | `main/`, `v2/` |
| 환경 | `dev`, `prd` | `dev/`, `prd/` |
| 모듈 | `snake_case` | `add_ons/` |
| 파일 | `name.tm.hcl`, `name.tf` | `stack.tm.hcl` |
| 생성 파일 | `_terramate_generated_*.tf` | `_terramate_generated_main.tf` |

---

## 변경 이력

| 날짜 | 버전 | 변경사항 |
|------|------|---------|
| 2025-11-19 | 1.0.0 | 네이밍 가이드 초기 생성 |

---

질문이나 제안사항이 있으시면 이슈를 생성하거나 PR을 제출해주세요.
