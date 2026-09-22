---
name: blog
description: 대화 중 좋은 아이디어/TIL을 블로그에 자동 포스팅. 회사/보안 관련 내용은 자동 필터링.
invocation:
  - /blog
  - 블로그 포스팅
  - 블로그에 올려줘
---

# Blog Auto-Posting Skill

대화 중 발견한 좋은 아이디어, TIL, 기술적 인사이트를 Hugo 블로그에 자동으로 포스팅합니다.

## Configuration

```
BLOG_REPO: ~/works/b100to.github.io-1
BLOG_URL: https://b100to.github.io
```

## Workflow

### 1. 포스팅할 내용 확인

사용자에게 어떤 내용을 블로그에 포스팅할지 확인합니다:
- 현재 대화에서 특정 주제 선택
- 사용자가 직접 주제 지정
- TIL 형식으로 자동 정리

### 2. 보안/회사 정보 필터링 (필수)

**절대 포함하면 안 되는 내용:**
- 회사명 (acme, 아크메 등 - 일반화하여 "현업", "실제 프로젝트"로 대체)
- AWS 계정 ID, ARN
- IP 주소, 도메인 (내부용)
- 비밀번호, API 키, 토큰
- 내부 시스템 이름, 서비스명 (구체적인 것)
- 인프라 구성의 구체적 수치 (인스턴스 수, 비용 등)
- 팀원 이름, 이메일

**필터링 방법:**
1. 회사명 → "현업 프로젝트", "실제 운영 환경"
2. 내부 서비스명 → "서비스 A", "백엔드 API" 등 일반화
3. 구체적 수치 → 범위로 표현 또는 생략
4. 특정 도메인 → "example.com"

### 3. 포스트 생성

Hugo 형식으로 포스트를 생성합니다:

**⚠️ 중요: 날짜는 반드시 현재 시간보다 과거로 설정**
- Hugo는 기본적으로 미래 날짜 포스트를 표시하지 않음
- `date` 명령어로 현재 시간 확인 후, 5-10분 전 시간으로 설정

```markdown
---
title: "제목"
date: {현재 시간보다 5-10분 전 ISO 8601 형식}+09:00
description: "SEO용 설명 (2-3문장)"
keywords: ["키워드1", "키워드2", ...]
categories: ["카테고리"]
tags: ["태그1", "태그2", ...]
showHero: true
heroStyle: "background"
---

본문 내용...
```

### 4. 파일 저장

```bash
# 디렉토리 생성 (slug는 kebab-case)
mkdir -p ~/works/b100to.github.io-1/content/posts/{slug}/

# index.md 저장
# 파일명: ~/works/b100to.github.io-1/content/posts/{slug}/index.md
```

### 5. Git 커밋 및 푸시

```bash
cd ~/works/b100to.github.io-1
git add content/posts/{slug}/
git commit -m "Add post: {제목}"
git push origin main
```

## 포스트 카테고리 가이드

| 카테고리 | 설명 |
|---------|------|
| Kubernetes | K8s, EKS, Karpenter 등 |
| Terraform | IaC, Terramate 등 |
| DevOps | CI/CD, GitOps, ArgoCD 등 |
| AWS | AWS 서비스 관련 |
| TIL | Today I Learned |
| Troubleshooting | 문제 해결 과정 |

## 포스트 톤 & 스타일

- **1인칭 주체적 관점 + 배려하는 톤**으로 작성
  - ❌ "AI가 참조할 수 있는 컨텍스트를 남겨두는 게 중요합니다" (설명해주는 느낌)
  - ❌ "내가 원하는 컨텍스트를 명확히 제공해야 한다" (단정적, 배려 부족)
  - ✅ "내가 원하는 컨텍스트를 명확히 제공하는 게 효과적이었다" (경험 공유)
  - ✅ "~해보니 좋았다", "~하는 편이 낫지 않을까 싶다" (부드럽게)
- "이게 맞다/저게 맞다" ❌ → "내 생각은 이러하다", "이럴 것 같다" ✅
- 독자를 배려하는 조심스러운 톤 유지
- 가르치는 느낌 ❌ → 의견/경험 공유 느낌 ✅
- 문제 → 해결 과정 → 결론 흐름
- 코드 예시 포함 (민감 정보 제거된)
- 실용적인 팁 강조

## LinkedIn 포스트 (linkedin.md)

블로그 글 작성 시 **함께 생성**합니다.

**톤**: 가벼운 느낌 - "간단한 팁 공유", "이렇게도 할 수 있구나"

**형식**:
```markdown
# LinkedIn 포스트용

https://b100to.github.io/posts/{slug}/

---

(한국어 본문 - 3~5문장으로 간결하게)

---

(English 본문 - 3~5문장으로 간결하게)

#DevOps #Kubernetes #Helm #Codex #GitOps
```

- 해시태그는 맨 끝에 한 줄만
- 블로그와 같은 폴더에 `linkedin.md`로 저장

## Example Usage

**사용자**: `/blog` 또는 "이거 블로그에 올려줘"

**Codex 응답 예시**:
```
블로그 포스팅을 준비할게요.

이번 대화에서 다룬 주요 주제들:
1. Karpenter Spot 인스턴스 가용성 문제 해결
2. ArgoCD Multi-source 배포 설정

어떤 주제로 포스팅할까요?
```

## 포스팅 전 체크리스트

### 보안 체크
- [ ] 회사명/서비스명이 일반화되었는가?
- [ ] AWS 계정 정보가 없는가?
- [ ] IP/도메인이 example로 대체되었는가?
- [ ] 비밀번호/토큰이 없는가?
- [ ] 구체적인 인프라 수치가 일반화되었는가?

### Hugo 체크
- [ ] `date`가 현재 시간보다 과거인가? (미래 날짜는 Hugo에서 표시 안 됨)
