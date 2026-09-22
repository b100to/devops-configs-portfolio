---
name: terraform-workflow
description: Terraform 및 Terramate 작업 시 사용하는 워크플로우 가이드
---

# Terraform & Terramate 워크플로우

이 레포지토리는 **Terramate**와 **Terraform**을 함께 사용하여 인프라를 관리합니다.

## 🚨 중요: Terramate 생성 파일 절대 수정 금지

### 1. Terramate 생성 파일 절대 수정 금지
**절대 `_terramate_generated_*.tf` 파일을 직접 수정하지 마세요!**

이 파일들은 Terramate가 자동으로 생성하는 파일입니다. 수정해도 다음 `terramate generate` 실행 시 덮어씌워집니다.

대신 Terramate 설정 파일(`.tm.hcl`)을 수정하세요.

#### 예시
```bash
# ❌ 잘못된 방법
vim stacks/acme/01_network/vpc/_terramate_generated_backend.tf

# ✅ 올바른 방법
vim stacks/acme/01_network/vpc/stack.tm.hcl
```

### 2. Terramate란?

Terramate는 Terraform 코드를 조직화하고 DRY(Don't Repeat Yourself) 원칙을 적용하기 위한 도구입니다.

**주요 기능**:
- **Stack 기반 관리**: 인프라를 논리적 단위(stack)로 분리
- **코드 생성**: 공통 설정(backend, provider 등)을 자동 생성
- **변경 감지**: 수정된 스택만 선택적으로 실행
- **순서 제어**: 스택 간 의존성 관리

## 📁 디렉토리 구조

```
.
├── modules/          # Terraform 모듈 정의
│   ├── 01_network/
│   ├── 02_compute/
│   ├── 04_database/
│   └── manifests/
│
├── stacks/           # Terramate 스택 (실제 인프라 배포 단위)
│   └── acme/
│       ├── 01_network/
│       │   └── vpc/
│       │       ├── stack.tm.hcl           # 스택 정의
│       │       ├── terramate.tm.hcl       # Terramate 설정
│       │       ├── main.tf                # Terraform 코드
│       │       └── _terramate_generated_*.tf  # 🚨 자동 생성 파일
│       ├── eks/
│       └── manifests/
│
└── terramate.tm.hcl     # 전역 Terramate 설정
```

## 🔧 일반적인 작업 흐름

### 1. 새로운 리소스 추가

#### 방법 A: 기존 스택에 추가
```bash
# 1. 스택 디렉토리로 이동
cd stacks/acme/01_network/vpc/

# 2. main.tf 또는 관련 .tf 파일 수정
vim main.tf

# 3. Terramate 생성 파일 갱신 (필요시)
terramate generate

# 4. 변경사항 확인
terraform plan

# 5. 적용
terraform apply
```

#### 방법 B: 새로운 스택 생성
```bash
# 1. 새 스택 디렉토리 생성
mkdir -p stacks/acme/03_new-category/new-stack/

# 2. 스택 설정 파일 생성
cd stacks/acme/03_new-category/new-stack/
vim stack.tm.hcl

# stack.tm.hcl 예시:
# stack {
#   name        = "new-stack"
#   description = "새로운 스택 설명"
#   id          = "uuid-here"
# }

# 3. Terraform 코드 작성
vim main.tf

# 4. Terramate 파일 생성
terramate generate

# 5. 초기화 및 적용
terraform init
terraform plan
terraform apply
```

### 2. 전역 설정 변경 (예: Backend, Provider)

```bash
# 1. 루트의 terramate.tm.hcl 또는 모듈별 .tm.hcl 수정
vim terramate.tm.hcl

# 2. 모든 스택의 생성 파일 갱신
terramate generate

# 3. 변경된 스택 확인
terramate list --changed

# 4. 변경된 스택에만 적용
terramate run terraform plan
```

### 3. 특정 스택만 작업

```bash
# 방법 1: 스택 디렉토리에서 직접 실행
cd stacks/acme/eks/cluster/
terraform plan
terraform apply

# 방법 2: Terramate로 특정 스택 실행
terramate run --tags eks terraform plan
```

## 📝 주요 Terramate 명령어

### 스택 관리
```bash
# 모든 스택 목록
terramate list

# 변경된 스택만 표시
terramate list --changed

# 특정 태그의 스택만 표시
terramate list --tags network
```

### 코드 생성
```bash
# 모든 스택의 생성 파일 갱신
terramate generate

# 특정 스택만 생성
cd stacks/acme/01_network/vpc/
terramate generate
```

### 실행 (로컬에서는 plan 확인만, apply는 CI/CD 자동)
```bash
# 모든 스택에서 plan 확인
terramate run terraform plan

# 변경된 스택만 plan
terramate run --changed terraform plan

# 특정 태그 스택만 plan
terramate run --tags database terraform plan

# 적용은 git push → CI/CD 자동 처리
git push
```

## ⚠️ 주의사항

### 1. Git 작업 시
```bash
# _terramate_generated_*.tf 파일도 반드시 커밋해야 합니다
git add .
git commit -m "Add new EKS nodegroup"
git push
```

### 2. Backend 설정
- Backend 설정은 Terramate가 생성하므로 `_terramate_generated_backend.tf` 확인
- S3 bucket, DynamoDB table 등은 미리 생성되어 있어야 함

### 3. 스택 의존성
- 스택 간 의존성이 있는 경우 순서 주의
- 예: VPC → EKS → Manifests 순서로 배포

### 4. State 관리
- 각 스택은 별도의 Terraform state를 가짐
- State는 S3 backend에 원격 저장
- 스택별로 독립적인 state 파일 존재

## 🔍 문제 해결

### Terramate 생성 파일이 최신이 아닐 때
```bash
# 모든 생성 파일 재생성
terramate generate

# 검증
terramate generate --check
```

### Terraform 초기화 문제
```bash
# Backend 설정 확인
cat _terramate_generated_backend.tf

# 초기화 재실행
terraform init -reconfigure
```

### 변경 감지가 안 될 때
```bash
# Git status 확인
git status

# Terramate 변경 감지 재실행
terramate list --changed
```

## 📚 베스트 프랙티스

1. **스택 분리 원칙**
   - 독립적으로 배포 가능한 단위로 스택 구성
   - 너무 세분화하면 관리 복잡도 증가
   - 적절한 크기: VPC, EKS cluster, RDS 등

2. **명명 규칙**
   - 스택 이름: `{카테고리}-{리소스명}` (예: `network-vpc`, `eks-cluster`)
   - 디렉토리: 숫자 prefix로 순서 표시 (예: `01_network`, `eks`)

3. **태그 활용**
   - 스택에 의미 있는 태그 부여
   - 환경별, 카테고리별 일괄 작업 가능

4. **모듈 재사용**
   - 공통 로직은 `modules/`에 모듈로 작성
   - 스택에서는 모듈을 호출만 하도록 구성

## 🔗 관련 링크

- [Terramate 공식 문서](https://terramate.io/docs)
- [Terraform 공식 문서](https://www.terraform.io/docs)

## 예시: EKS 노드그룹 추가

```bash
# 1. 스택으로 이동
cd stacks/acme/eks/nodegroups/

# 2. main.tf에 노드그룹 추가
vim main.tf

# 3. 변경사항 확인
terraform plan

# 4. 적용
terraform apply

# 5. Git 커밋 (생성 파일 포함)
git add .
git commit -m "Add new EKS nodegroup for batch workloads"
git push
```
