---
name: weekly-report
description: 주간 회의 보고서 자동 생성. git 커밋, 세션 기록 등에서 작업 내용 수집하여 정형화된 보고서 작성.
invocation:
  - /weekly-report
  - 주간보고
  - 주간 회의
  - weekly report
---

# Weekly Report Generation Skill

주간 작업 내용을 수집하여 정형화된 보고서를 자동으로 생성합니다.

## 데이터 소스

### 1. Git 커밋 로그
```bash
# 이번 주 커밋 (월~금)
git log --since="last monday" --until="now" --oneline --all

# 특정 기간 지정 시
git log --since="2026-01-20" --until="2026-01-24" --oneline --all
```

### 2. 세션 기록
- 위치: `~/.claude/sessions/devops-configs/`
- 파일: `{YYYY-MM-DD}-{주제}.md`

### 3. ArgoCD 동기화 기록 (선택)
```bash
argocd app list --output json | jq '.[] | {name, syncStatus, health}'
```

## 보고서 형식

### 기본 템플릿

```markdown
# 주간 업무 보고

**작성일**: {오늘 날짜}
**기간**: {시작일} ~ {종료일}

---

# {작업 내용에 맞는 키워드}
  - {작업 내용} ({날짜}, {요청팀/비고})
  - {작업 내용} ({날짜})
      -> {후속 작업 또는 결과} ({날짜})

---

# 차주 예정
  - {예정 작업}
```

### 작성 규칙
- 각 항목에 **(날짜)** 필수 포함
- 요청 작업은 **(날짜, 요청팀)** 형식
- 후속 작업은 `->` 로 연결
- 중요도 순 정렬 (prd > dev > 문서화)
- **카테고리(키워드)는 작업 내용에 맞게 자유롭게 설정**
- **⚠️ 할루시네이션 금지: 커밋/세션 기록에 없는 내용 절대 작성 금지**
- **⚠️ 보고서 제출 시 "~가 누락되어 추가", "~가 빠져있어서 보완" 등의 표현 금지. 작업한 내용만 제시할 것.**

## 카테고리 예시

작업 내용 보고 알아서 판단:
- EKS, Terraform, IRSA → `# 인프라`
- 모니터링, 장애 대응 → `# 운영`
- 문서 작성 → `# 문서화`
- 연차, 회의 → `# 기타`
- Karpenter 관련 → `# Karpenter`
- Pod Identity 전환 → `# IRSA 전환`

고정된 카테고리 없음. 그 주에 한 작업에 맞게 키워드 선택.

## Workflow

### 1. 기간 확인
```
사용자에게 보고서 기간을 확인합니다:
- 이번 주 (기본값: 월요일 ~ 오늘)
- 지난 주
- 특정 기간 지정
```

### 2. 데이터 수집

**⚠️ 중요: 커밋 메시지만으로는 부족함. 반드시 변경된 파일까지 확인할 것!**

```bash
# Git 커밋 + 변경 파일 함께 수집 (필수)
git log --since="{start_date}" --until="{end_date}" \
  --pretty=format:"%h %ad %s" --date=short --all --name-only

# 세션 기록 확인
ls -la ~/.claude/sessions/devops-configs/
```

변경된 파일 목록을 보면:
- 어떤 환경(dev/prd)에 작업했는지
- 어떤 앱/서비스에 영향이 있는지
- 작업의 실제 범위가 얼마나 되는지

파악 가능함.

### 2-1. 커밋 메시지가 부실할 때

커밋 메시지가 "Refactor", "Update" 등 모호하면 **변경 파일을 직접 확인**:

```bash
# 특정 커밋의 변경 내용 확인
git show {commit_hash} --stat
git diff {commit_hash}^..{commit_hash}
```

**파일 경로로 작업 내용 유추**:
| 파일 경로 패턴 | 의미 |
|---------------|------|
| `values/apps/{app}/dev.yaml` | {app} dev 환경 설정 변경 |
| `values/apps/{app}/prd.yaml` | {app} prd 환경 설정 변경 |
| `values/infra/monitoring/*` | 모니터링 스택 설정 |
| `modules/*` | Terraform 모듈 수정 |
| `stacks/*/config.tm.hcl` | Terramate 스택 설정 |
| `argocd/*` | ArgoCD Application 설정 |
| `.claude/skills/*` | Claude Code 스킬 추가/수정 |

변경된 파일 수가 많으면 작업 범위 큼 → 보고서에 구체적으로 기술.

### 3. 내용 분류
- 커밋 메시지 + 변경 파일 분석하여 카테고리 자동 분류
- 세션 기록의 "요약" 섹션 추출
- 중복 제거 및 그룹화
- 같은 작업의 여러 커밋은 하나로 통합 (예: 환경변수 시행착오 → "환경변수 설정")

### 4. 보고서 생성
- 템플릿에 맞춰 정리
- 글머리 기호로 계층 구조화
- 구체적인 기술 용어 포함
- **중요도 순으로 작성** (영향 범위 큰 작업 → 작은 작업)

**중요도 판단 기준**:
| 우선순위 | 작업 유형 | 예시 |
|---------|----------|------|
| 높음 | prd 환경 변경, 인프라 핵심 변경 | IRSA 전환, EKS 업그레이드 |
| 중간 | dev 환경 변경, 설정 최적화 | 리소스 조정, Karpenter 설정 |
| 낮음 | 문서화, 스킬 추가, 정리 작업 | CLAUDE.md 수정, _defaults.yaml 정리 |

### 5. 시트용 압축 버전 생성

보고서 생성 시 **상세 마크다운**과 **시트용 압축본**을 동시에 만듦:

| 출력물 | 용도 | 상세도 |
|--------|------|--------|
| 마크다운 파일 | 상세 기록 보관 | 날짜, 후속작업(`->`), 세부 항목 모두 포함 |
| 시트 압축본 | 5분 발표용 | 카테고리 4~5개, 항목당 1줄, 비전문가도 이해 가능 |

**압축 원칙**:
1. **카테고리 4~5개 이내** — 관련 작업끼리 통합 (예: Karpenter + 서비스 안정화 → "모니터링/안정화")
2. **카테고리당 항목 2개** — 각 항목 1줄로 완결
3. **작업 우선순위 순 나열** — 영향 범위 큰 작업이 위 (prd 인프라 > 운영 > 자동화 > 내부 툴)
4. **성과 중심 서술** — "뭘 했다"가 아니라 "뭐가 됐다" (예: "전환 완료", "배포 완료")
5. **비전문가 이해 가능** — 기술 약어 풀어쓰기 또는 괄호 보충, 세부 기술 파라미터 제거
6. 날짜 제거 (시트에는 주차 라벨로 충분)

**예시 (마크다운 → 시트)**:
```
# 마크다운 (상세, 8개 카테고리)
# EKS v2 전환
  - PRD v1→v2 DNS 전환 (내부 인프라 1단계 완료, 가중치 마이그레이션 스크립트 작성)
  - mall-v3-beat, mall-v4-batch PRD v2 이전 완료
  - v1 PRD 전체 NodePool CPU limit 0 설정 (v2 전환 완료)
  - PRD EKS 1.35 업그레이드, ALB WAF/접근 로그 활성화
# Karpenter
  - PRD AMI 버전 고정, Airflow spot→on-demand 전환
  - batch NodePool 인스턴스/CPU 조정, IAM 권한 추가
# 서비스 안정화
  - homepage, mall-reco-api 이중화, HPA min 2, ArgoCD OOM 방지
  ...

# 시트 (압축, 4개 카테고리, 우선순위 순)
[EKS v2 전환]
  - PRD 클러스터 v1→v2 전환 완료 (DNS, 서비스 이전, 기존 클러스터 정리)
  - WAF 보안 설정 및 접근 로그 활성화
[모니터링/안정화]
  - Datadog 전환 완료 (기존 Prometheus 제거), 클러스터 모니터링 안정화
  - 주요 서비스 이중화 및 장애 대비 설정
[인프라 자동화]
  - Authentik SSO 배포 (sso.acme.example)
  - Terraform 스택 추가 (외부 시크릿, IAM, 스토리지)
[Stockroom (창고지기)]
  - company-supply → stockroom 리브랜딩, PRD 배포 완료
  - 어드민/메인 페이지 기능 및 UI 개선, 모니터링 알림 설정
```

### 6. 차주 예정 작성
- 진행 중인 작업에서 추출
- TODO 항목 참조
- 사용자에게 추가 내용 질의

### 7. 출력 및 배포

**두 가지 버전 모두 마크다운 파일로 저장**:

| 버전 | 파일명 | 내용 |
|------|--------|------|
| 상세본 (풀버전) | `docs/logs/weekly/{YYYY-MM}-{N}W.md` | 날짜, 후속작업, 세부 항목 모두 포함 |
| 압축본 (요약) | `docs/logs/weekly/{YYYY-MM}-{N}W-summary.md` | 카테고리당 2~4개, 시트/회의용 |

**저장 순서**:
1. 상세본 마크다운 저장 → `docs/logs/weekly/{YYYY-MM}-{N}W.md`
2. 압축본 마크다운 저장 → `docs/logs/weekly/{YYYY-MM}-{N}W-summary.md`
3. **⚠️ 사용자 검토 (필수)**: 압축본 내용을 보여주고 AskUserQuestion으로 검토 요청
   - 수정할 내용이 있으면 반영 후 다시 검토
   - 승인 받은 후에만 시트 등록 진행
4. 사용자에게 Google Sheets 등록 여부 질문
5. Yes → 압축본을 시트에 등록 (export_to_sheets.py 사용, 압축본 파일 경로 전달)

## Example Usage

**사용자**: `/weekly-report` 또는 "이번 주 주간보고 만들어줘"

**Claude 응답**:
```
주간 보고서를 생성할게요.

보고서 기간을 확인합니다:
1. 이번 주 (2026-01-20 ~ 2026-01-24)
2. 지난 주 (2026-01-13 ~ 2026-01-17)
3. 직접 지정

어떤 기간으로 할까요?
```

## 보고서 작성 팁

### 날짜 표시
- **작성일**: 오늘 날짜 (보고서 작성 시점)
- **기간**: 실제 작업 기간 (월요일 ~ 오늘)
- 한국 시간 기준 (월요일이 주의 시작)

### 작업 내용 기술 방식
- **구체적으로**: "인프라 작업" ❌ → "EKS v1.30 업그레이드 완료" ✅
- **성과 중심**: "작업 진행 중" ❌ → "전환 완료 및 검증 완료" ✅
- **수치 포함**: "대부분 완료" ❌ → "전체 15개 중 14개 완료 (93%)" ✅

### 차주 예정 작성
- 구체적인 목표 명시
- 우선순위 표시 (필요시)
- 완료 예상일 포함 (가능시)

## 출력 옵션

### 1. 마크다운 (기본)
터미널에 출력

### 2. 파일 저장 (권장)
```bash
# 저장 위치 (주차 단위)
docs/logs/weekly/{YYYY-MM}-{N}W.md
# 예: docs/logs/weekly/2026-01-4W.md

# 주차 계산: 해당 월의 첫 월요일부터 1주차
# 폴더 생성 (최초 1회)
mkdir -p docs/logs/weekly
```

**⚠️ 같은 주차 파일이 있으면 덮어쓰지 말고 이어서 작성!**

같은 주에 여러 번 작성할 수 있음:
- 월요일 10시 → 월요일 13시 추가 작업
- 월요일 작성 → 수요일 추가 작성

같은 주차 파일이 있으면:
1. 기존 내용 읽기
2. 새 작업 내용만 추가 (중복 제거)
3. 차주 예정 업데이트

### 3. 클립보드 복사
macOS: `pbcopy`로 클립보드에 복사

### 4. Google Sheets 등록

보고서를 Google Sheets API v4로 직접 등록합니다.
- **Alex** 시트에 주차 기준 정렬 삽입 (최신이 위, 과거가 아래)
- 같은 주차가 이미 있으면 업데이트, 없으면 새 행 삽입
- 카테고리명 볼드 처리 (Rich Text: `textFormatRuns`)
- 셀 서식: Noto Sans KR 10pt, 패딩 (상하좌우 8px), 얇은 테두리
- 행 높이 자동 조절 (`autoResizeDimensions`)

**시트용 항목 압축**: Workflow 5단계 참조 (카테고리당 2~4개, 회의 보고용 요약)

**초기 설정 (1회)**:
1. Google Cloud Console에서 서비스 계정 생성 + Sheets API 활성화
2. JSON 키 다운로드 → `.claude/skills/weekly-report/references/service-account.json`
3. 대상 스프레드시트를 서비스 계정 이메일과 공유 (편집자 권한)

**사용법** (uv):
```bash
SCRIPT=.claude/skills/weekly-report/scripts/export_to_sheets.py

# 실제 등록 (기본: Alex 시트)
uv run --python 3.13 --with google-auth --with google-api-python-client \
  $SCRIPT --file docs/logs/weekly/2026-01-4주차.md --sheet-id <SPREADSHEET_ID>

# 파싱 결과 확인 (시트에 쓰지 않음)
uv run --python 3.13 --with google-auth --with google-api-python-client \
  $SCRIPT --file docs/logs/weekly/2026-01-4주차.md --sheet-id <SPREADSHEET_ID> --dry-run

# 다른 워크시트 지정
uv run --python 3.13 --with google-auth --with google-api-python-client \
  $SCRIPT --file docs/logs/weekly/2026-01-4주차.md --sheet-id <SPREADSHEET_ID> --worksheet "Blake"
```

**시트 구조 (A~D, 4열)**:
| 컬럼 | 내용 | 서식 | 예시 |
|------|------|------|------|
| A: 주차 | 보고서 기간 → 주차 라벨 | 가운데 정렬 | `2026-01 4W` |
| B: 금주 업무 | 전체 카테고리 + 항목 (Rich Text) | 왼쪽 정렬 | `[EKS v2]\n  - 작업...` |
| C: 차주 예정 | `# 차주 예정` 항목 | 왼쪽 정렬 | `- 예정 작업...` |
| D: 특이 사항 | (수동 입력용, 빈 셀) | 왼쪽 정렬 | |

**Spreadsheet ID 확인**: 스프레드시트 URL `https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit` 에서 추출

## 보안 주의사항

- 내부 서비스명은 그대로 사용 (내부 보고서이므로)
- AWS 계정 ID, 비밀번호 등은 포함하지 않음
- 민감한 장애 내용은 일반화하여 기술

## 추가 기능 (선택)

### 외부 프로젝트 지원 포함 시
```markdown
## 🏢 외부 프로젝트 지원

### {프로젝트명} (예: 아크메, 오빗)
* {지원 내용}
  - {세부 사항}
```
