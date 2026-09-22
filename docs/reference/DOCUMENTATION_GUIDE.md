# Documentation Guide

## 📚 문서 구조 (`docs/`)

문서는 목적에 따라 다음 구조로 관리됩니다:

- **`reference/`**: 정책, 아키텍처, 가이드 등 Single Source of Truth (예: 네이밍 가이드, 인증 표준)
- **`runbooks/`**: 운영 절차, 트러블슈팅, 수동 작업 내역 등 How-to 문서
- **`incidents/`**: 장애 보고서 및 포스트모템
- **`logs/`**: 작업 이력 (daily, weekly, session logs) - 검색용 아카이브이며 운영 기준으로 사용하지 않음
- **`archive/`**: Deprecated 문서 및 과거 이력

## 🚀 자동화 방법 (Terraform Docs)

### 1. Pre-commit Hook (추천)

Pre-commit hook이 설정되어 있어, 커밋할 때 자동으로 문서가 업데이트됩니다.

```bash
# Pre-commit 설치 (최초 1회)
pre-commit install

# 이후 커밋할 때 자동 실행됨
git add .
git commit -m "feat: Add new stack"
# → terraform-docs가 자동으로 README.md 업데이트
```

### 2. 수동 실행

모든 스택의 문서를 한번에 생성:

```bash
scripts/generate-docs.sh
```

특정 스택만 생성:

```bash
cd stacks/acme/eks/prd
terraform-docs -c ../../../../.terraform-docs.yml .
```

## 📁 파일 구조

```
.
├── .terraform-docs.yml          # 전역 설정 (모든 스택에서 공유)
├── .pre-commit-config.yaml      # Pre-commit 설정
├── scripts/
│   └── generate-docs.sh         # 전체 문서 생성 스크립트
└── stacks/
    └── {project}/
        └── {resource}/
            └── {env}/
                ├── *.tf                    # Terraform 파일
                └── README.md               # 자동 생성됨 ✨
```

## 🆕 새 스택 생성 시

### 방법 1: Pre-commit 활용 (자동)

1. 새 스택 디렉토리와 Terraform 파일 생성
2. Terramate generate 실행 (필요시)
3. Git add & commit
4. **자동으로 README.md 생성됨!** ✨

```bash
# 예시
mkdir -p stacks/acme/rds/v1/prd
# ... Terraform 파일 작성 ...
git add stacks/acme/rds/v1/prd
git commit -m "feat: Add RDS v1 stack"
# → README.md 자동 생성
```

### 방법 2: 스크립트 사용 (수동)

```bash
# 모든 스택 문서 업데이트
scripts/generate-docs.sh

# Git에 추가
git add stacks/*/README.md
git commit -m "docs: Update all stack documentation"
```

## ⚙️ .terraform-docs.yml 설정

루트의 `.terraform-docs.yml` 파일에서 문서 형식을 관리합니다:

- **formatter**: `markdown table` - 표 형식으로 출력
- **sections**: Requirements, Providers, Inputs, Outputs, Resources 포함
- **sort**: 이름순 정렬
- **output**: README.md에 injection

필요시 이 파일을 수정하여 문서 형식을 변경할 수 있습니다.

## 📝 README.md 구조

각 스택의 README.md는 다음을 포함합니다:

```markdown
<!-- BEGIN_TF_DOCS -->

## Overview
스택 설명

## Requirements
Terraform 및 Provider 버전

## Providers
사용된 Provider 목록

## Inputs
입력 변수 (타입, 기본값, 필수 여부)

## Outputs
출력 값

## Resources
생성되는 리소스 목록

<!-- END_TF_DOCS -->
```

⚠️ `<!-- BEGIN_TF_DOCS -->` ~ `<!-- END_TF_DOCS -->` 사이는 자동 생성되므로 **직접 수정하지 마세요!**

## 🔧 Troubleshooting

### "terraform-docs not found"

```bash
# asdf 사용자
asdf plugin add terraform-docs
asdf install terraform-docs latest
asdf global terraform-docs latest

# Homebrew 사용자
brew install terraform-docs
```

### Pre-commit이 작동하지 않음

```bash
# Pre-commit 재설치
pre-commit uninstall
pre-commit install

# 캐시 정리
pre-commit clean

# 모든 파일에 대해 실행
pre-commit run --all-files
```

### 특정 스택만 문서 업데이트

```bash
cd stacks/acme/eks/v2/prd
terraform-docs -c ../../../../.terraform-docs.yml .
```

## 💡 Best Practices

1. **커밋 전 확인**: Pre-commit이 설치되어 있는지 확인
2. **의미있는 주석**: Terraform 변수에 description 추가
3. **정기적 업데이트**: 주기적으로 `scripts/generate-docs.sh` 실행
4. **수동 섹션 추가**: 필요시 `<!-- END_TF_DOCS -->` 아래에 추가 문서 작성 가능

## 📚 참고자료

- [terraform-docs 공식 문서](https://terraform-docs.io/)
- [Pre-commit 공식 문서](https://pre-commit.com/)
