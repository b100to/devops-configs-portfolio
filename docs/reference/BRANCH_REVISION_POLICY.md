# ArgoCD targetRevision 브랜치 정책

## 기본 규칙
- 모든 ArgoCD Application의 `targetRevision`은 **`main`** 브랜치를 기본으로 사용합니다.
- 개발/테스트 목적의 임시 브랜치 사용은 허용되나, 작업 완료 후 반드시 `main`으로 복구해야 합니다.
- 영구적인 예외 브랜치 사용은 아래 예외 목록에 등록된 경우만 허용됩니다.

## 예외 목록

| app | env | targetRevision | reason | owner | last_reviewed_date |
|-----|-----|----------------|--------|-------|--------------------|
| mall/v4-batch | dev, prd | `mall/v4/batch` | GitHub Actions 이미지 태그 변경 시 자동 커밋으로 인한 main 브랜치 오염 방지 | DevOps | 2026-02-24 |

## 변경/승인 절차
1. 새로운 예외 브랜치가 필요한 경우, 본 문서의 '예외 목록'에 항목을 추가하는 PR을 생성합니다.
2. PR 내용에 예외가 필요한 명확한 사유(reason)를 기재합니다.
3. DevOps 팀의 리뷰 및 승인을 받습니다.
4. 승인 완료 후 ArgoCD Application 매니페스트에 예외 브랜치를 적용합니다.

## 검증 체크리스트
- [ ] `targetRevision`이 `main`이 아닌 경우, 예외 목록에 등록되어 있는가?
- [ ] 예외 브랜치에 필요한 Helm chart 및 values 파일이 올바르게 존재하는가?
- [ ] 예외 브랜치가 삭제되거나 관리되지 않고 방치되어 있지 않은가?
