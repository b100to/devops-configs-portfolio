# Terramate/Terraform 구조 가이드

이 문서는 imports, modules, stacks 폴더 구조와 globals, locals, variables의 역할을 설명합니다.

## 폴더 구조 개요

```
/
├── config.tm.hcl                    # 전역 설정 (버전 정보)
├── imports/                      # 재사용 가능한 generate_hcl 블록
├── modules/                      # 모듈별 Terraform 코드 템플릿
└── stacks/                       # 실제 실행되는 스택 (환경별)
```

---

## imports/

**역할**: 여러 스택에서 공통으로 사용하는 `generate_hcl` 블록 정의

```
imports/
├── backend.tm.hcl           # S3 backend 설정 생성
└── providers/
    └── providers.tm.hcl     # 통합 providers (condition으로 분기)
```

### providers.tm.hcl 구조

`provider_preset`으로 스택별로 필요한 provider만 포함합니다.

| Preset | Providers | 용도 |
|--------|-----------|------|
| `aws` (기본) | aws | VPC, IAM, PIA |
| `helm` | aws, helm, kubernetes | Helm chart 설치 |
| `manifests` | aws, kubectl, kubernetes | kubectl manifests 배포 |
| `eks` | aws, helm, kubectl, kubernetes, tls | EKS 클러스터 생성 |

### 스택별 globals 설정

```hcl
# VPC, IAM, PIA (기본값 = aws)
globals {
  # provider_preset 생략하면 "aws"
}

# EKS 생성
globals {
  provider_preset = "eks"
}

# Helm 설치 (helm)
globals {
  provider_preset            = "helm"
  enable_k8s_provider_config = true   # 클러스터 연결 설정
}

# Manifests 배포 (manifests)
globals {
  provider_preset            = "manifests"
  enable_k8s_provider_config = true
}
```

### 예시: backend.tm.hcl

```hcl
generate_hcl "_terramate_generated_backend.tf" {
  content {
    terraform {
      backend "s3" {
        region  = global.region
        bucket  = tm_join("-", [global.domain, "tfstate", global.environment])
        key     = "${tm_replace("${terramate.stack.id}", "_", "/")}/terraform.tfstate"
        encrypt = true
      }
    }
  }
}
```

→ `global.*` 값을 사용해 환경별로 다른 backend 설정 생성

---

## modules/

**역할**: 리소스별 Terraform 코드 템플릿 (generate_hcl 블록)

```
modules/
├── vpc/
│   ├── locals.tm.hcl        # locals 블록 생성
│   ├── main.tm.hcl          # module "vpc" 정의
│   └── outputs.tm.hcl       # output 블록 생성
├── eks/
│   ├── locals.tm.hcl        # locals 블록 (global.* 참조)
│   ├── main.tm.hcl          # module "eks" 정의
│   ├── variables.tm.hcl     # variable 블록 (기본값 포함)
│   └── outputs.tm.hcl       # output 블록
└── ...
```

### 파일별 역할

| 파일 | 생성되는 TF 파일 | 역할 |
|------|------------------|------|
| locals.tm.hcl | _terramate_generated_locals.tf | globals → locals 변환 |
| main.tm.hcl | _terramate_generated_main.tf | 실제 리소스/모듈 정의 |
| variables.tm.hcl | _terramate_generated_variables.tf | 입력 변수 정의 |
| outputs.tm.hcl | _terramate_generated_outputs.tf | 출력 값 정의 |

### 예시: locals.tm.hcl (EKS)

```hcl
generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      # global.* 값을 사용해 리소스 이름 생성
      name = tm_join("-", [global.domain, "main", global.version, global.environment])

      # input 블록에서 받은 값 사용
      vpc_id     = var.vpc_id
      subnet_ids = var.private_subnet_ids
    }
  }
}
```

---

## stacks/

**역할**: 실제 실행되는 Terraform 워크스페이스 (환경별)

```
stacks/
├── config.tm.hcl                           # 공통 globals (region, tags)
└── acme/
    └── eks/
        ├── config.tm.hcl                   # globals (resource = "eks")
        └── main/
            ├── config.tm.hcl               # globals (version, 공통 설정)
            ├── import.tm.hcl               # imports, modules 연결
            ├── dev/
            │   ├── config.tm.hcl           # globals (environment, account_id)
            │   ├── stack.tm.hcl            # 스택 정의 + input 블록
            │   └── tfvars.tm.hcl           # 환경별 변수 오버라이드
            └── prd/
                ├── config.tm.hcl
                ├── stack.tm.hcl
                └── tfvars.tm.hcl
```

### 파일별 역할

| 파일 | 역할 |
|------|------|
| config.tm.hcl | globals 정의 (계층별로 상속됨) |
| import.tm.hcl | imports, modules 파일 가져오기 |
| stack.tm.hcl | 스택 메타데이터 + 다른 스택 output 참조 (input) |
| tfvars.tm.hcl | 환경별 변수 오버라이드 |

### 예시: import.tm.hcl

```hcl
import {
  source = "/imports/providers/providers.tm.hcl"
}

import {
  source = "/modules/eks/*.tm.hcl"
}
```

### 예시: stack.tm.hcl

```hcl
stack {
  name = "acme_eks_main_v2_dev"
  id   = "acme_eks_main_v2_dev"
  tags = ["stack", "acme", "eks", "v2", "dev"]

  after = ["tag:dev:vpc"]  # VPC 스택 먼저 실행
}

# 다른 스택의 output을 input으로 받기
input "vpc_id" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_dev"
  value         = outputs.vpc_id.value
  mock          = "MOCK"
}
```

---

## globals 상속 체인

globals는 상위 디렉토리에서 하위로 자동 상속됩니다.

```
/config.tm.hcl
  terraform_version = "1.13.5"
  terraform_aws_provider_version = "~> 6.21.0"
      ↓ 상속
/stacks/config.tm.hcl
  region = "ap-northeast-2"
  tags = { ... }
      ↓ 상속
/stacks/acme/eks/config.tm.hcl
  resource = "eks"
      ↓ 상속
/stacks/acme/eks/main/config.tm.hcl
  version = "v2"
  cluster_version = "1.34"
      ↓ 상속
/stacks/acme/eks/main/dev/config.tm.hcl
  environment = "dev"
  account_id = "111111111111"
```

하위에서 같은 이름의 global을 정의하면 오버라이드됩니다.

---

## globals vs locals vs variables

### 핵심 원칙

| 구분 | 용도 | 위치 | 예시 |
|------|------|------|------|
| **globals** | 환경별 원시 데이터 | config.tm.hcl | `environment`, `account_id`, `region` |
| **locals** | globals 조합/계산값 | modules/*/locals.tm.hcl | `cluster_name = "${domain}-${env}"` |
| **variables** | 외부 모듈 설정값 (기본값 필요) | modules/*/variables.tm.hcl | `github_repositories`, `iam_role_policy_arns` |
| **tfvars** | 환경별 variable 오버라이드 | stacks/.../tfvars.tm.hcl | `coredns_replica_count = 3` |
| **input** | 스택 간 output 전달 | stack.tm.hcl | `vpc_id`, `subnet_ids` |

### 올바른 패턴

```hcl
# ✅ 좋은 예: globals에서 원시 데이터, locals에서 조합
# config.tm.hcl
globals {
  environment = "dev"
  domain      = "acme"
}

# locals.tm.hcl
locals {
  name = "${global.domain}-${global.environment}"  # 조합은 locals에서
}

# main.tm.hcl
module "eks" {
  cluster_name = local.name  # locals 참조
  tags         = global.tags # 단순 값은 globals 직접 참조 가능
}
```

### 피해야 할 패턴

```hcl
# ❌ 나쁜 예: variables에 하드코딩된 default
# variables.tm.hcl
variable "iam_role_policy_arns" {
  default = ["arn:aws:iam::aws:policy/AdministratorAccess"]  # 환경별로 다를 수 있는 값
}

# ✅ 수정: globals로 이동
# config.tm.hcl
globals {
  iam_role_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

# main.tm.hcl
module "oidc" {
  iam_role_policy_arns = global.iam_role_policy_arns
}
```

### 언제 무엇을 사용하나?

| 상황 | 사용할 것 |
|------|----------|
| 환경별로 다른 값 (account_id, environment) | globals |
| 모든 환경에서 동일한 값 | 상위 config.tm.hcl의 globals |
| 여러 곳에서 반복되는 계산식 | locals |
| 다른 스택의 output 참조 | input 블록 |
| 외부 모듈의 선택적 파라미터 | variables (기본값 필요 시) |

---

### globals (Terramate)

```hcl
# config.tm.hcl
globals {
  environment = "dev"
  account_id  = "111111111111"
  region      = "ap-northeast-2"
}
```

- **위치**: config.tm.hcl
- **용도**: Terramate 레벨 변수, 코드 생성 시 사용
- **상속**: 상위 → 하위 디렉토리로 자동 상속
- **참조**: `global.environment`, `global.account_id`

**사용 시점**:
- 환경별로 다른 값 (environment, account_id)
- 리소스 이름 조합에 필요한 값 (domain, version)
- 태그, 리전 등 공통 설정

### locals (Terraform)

```hcl
# modules/eks/locals.tm.hcl
generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      name = tm_join("-", [global.domain, "main", global.version, global.environment])
    }
  }
}
```

- **위치**: modules/*/locals.tm.hcl
- **용도**: Terraform locals 블록 생성
- **상속**: 없음 (각 스택에서 독립적으로 생성)
- **참조**: `local.name`

**사용 시점**:
- globals 조합하여 복잡한 값 계산
- 반복 사용되는 표현식

### variables (Terraform)

```hcl
# modules/eks/variables.tm.hcl
generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "coredns_replica_count" {
      description = "Number of replicas for CoreDNS"
      type        = number
      default     = 1
    }
  }
}
```

- **위치**: modules/*/variables.tm.hcl
- **용도**: Terraform variable 블록 생성
- **오버라이드**: tfvars.tm.hcl로 환경별 값 설정

**사용 시점**:
- 모듈 레벨의 설정값
- 기본값이 있고 환경별로 다를 수 있는 값

### input (Terramate)

```hcl
# stack.tm.hcl
input "vpc_id" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_dev"
  value         = outputs.vpc_id.value
  mock          = "MOCK"
}
```

- **위치**: stack.tm.hcl
- **용도**: 다른 스택의 output을 현재 스택에서 사용
- **참조**: var.vpc_id (variables처럼 참조)

**사용 시점**:
- 스택 간 의존성 (VPC → EKS → Karpenter)

---

## 데이터 흐름 다이어그램

```
┌─────────────────────────────────────────────────────────────────┐
│                        config.tm.hcl                            │
│  globals { terraform_version, provider_versions }               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   stacks/config.tm.hcl                       │
│  globals { region, tags }                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              stacks/.../dev/config.tm.hcl                    │
│  globals { environment = "dev", account_id = "..." }            │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            │                                   │
            ▼                                   ▼
┌───────────────────────┐           ┌───────────────────────┐
│   imports/*.hcl    │           │   modules/*.hcl    │
│  (providers, backend) │           │  (locals, main, vars) │
└───────────────────────┘           └───────────────────────┘
            │                                   │
            │       ┌───────────────────┐       │
            └──────►│   import.tm.hcl   │◄──────┘
                    │  (연결)            │
                    └───────────────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ _terramate_       │
                    │ generated_*.tf    │
                    │ (최종 TF 코드)     │
                    └───────────────────┘
```

---

## 자주 묻는 질문

### Q: 새 환경별 값은 어디에 추가해야 하나요?

**A**: stacks/.../dev/config.tm.hcl 또는 prd/config.tm.hcl의 globals 블록에 추가

```hcl
globals {
  environment = "dev"
  account_id  = "111111111111"
  my_new_value = "something"  # 새 값 추가
}
```

### Q: 모든 환경에서 같은 값을 사용하려면?

**A**: 상위 config.tm.hcl에 정의 (예: main/config.tm.hcl)

```hcl
# stacks/acme/eks/main/config.tm.hcl
globals {
  version = "v2"
  cluster_version = "1.34"  # dev, prd 모두 같은 값
}
```

### Q: 특정 환경에서만 변수를 오버라이드하려면?

**A**: tfvars.tm.hcl 사용

```hcl
# stacks/.../prd/tfvars.tm.hcl
generate_hcl "_terramate_generated_.auto.tfvars" {
  content {
    coredns_replica_count = 3  # prd에서만 3개
  }
}
```

### Q: 새 모듈을 추가하려면?

1. `modules/XX_new_module/` 폴더 생성
2. locals.tm.hcl, main.tm.hcl, variables.tm.hcl, outputs.tm.hcl 작성
3. `stacks/.../import.tm.hcl`에서 import

```hcl
import {
  source = "/modules/XX_new_module/*.tm.hcl"
}
```

---

## 관련 명령어

> apply/init/destroy는 CI/CD가 자동 처리. 로컬에서는 plan 확인과 state 조작만 허용.

```bash
# 스택 목록 확인
terramate list

# 특정 스택 plan (확인용)
terramate run --tags=dev:eks --enable-sharing --mock-on-fail -- terraform plan

# 변경된 스택만 plan
terramate run --tags=dev --changed --enable-sharing --mock-on-fail -- terraform plan
```
