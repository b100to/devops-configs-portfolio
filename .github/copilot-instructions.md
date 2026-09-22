# DevOps Configurations Repository - GitHub Copilot Instructions

이 저장소는 Kubernetes 클러스터의 인프라 및 애플리케이션 설정을 관리하는 GitOps 레포지토리입니다.

## 🚨 중요: GitOps 워크플로우

### 절대 금지 사항
**`kubectl apply`, `kubectl create`, `kubectl patch` 등의 직접 배포 명령어를 사용하지 마세요.**

### 배포 방식
- 이 레포의 모든 Kubernetes 리소스는 **ArgoCD**를 통해 자동으로 배포됩니다
- 파일을 수정하고 Git에 커밋하면 ArgoCD가 자동으로 클러스터에 동기화합니다
- **Terraform을 제외한** 모든 인프라/애플리케이션은 ArgoCD로 관리됩니다

### 올바른 배포 프로세스
1. 매니페스트 파일 생성/수정
2. Git에 커밋 및 푸시
3. PR 생성 및 리뷰 (선택)
4. main 브랜치에 머지
5. ArgoCD가 자동으로 감지하고 배포

## 📁 레포지토리 구조

### 주요 디렉토리

#### `argocd/`
ArgoCD AppProject 및 Application 정의 (**App of Apps 패턴**)
- `dev/` - 개발 환경 설정
  - `apps/` - 애플리케이션 Application 정의
  - `infra/` - 인프라 Application 정의
  - `proj/` - AppProject 정의 (있는 경우)
- `prd/` - 프로덕션 환경 설정
  - `apps/` - 애플리케이션 Application 정의
  - `infra/` - 인프라 Application 정의
  - `proj/` - AppProject 정의 (있는 경우)

**App of Apps 구조**:
```
Terraform/Terramate (초기 부트스트랩)
└─ root-app-v2 생성
   └─ argocd/{env}/ 디렉토리 자동 모니터링
      ├─ apps/ (모든 Application 자동 배포)
      └─ infra/ (모든 Application 자동 배포)
```

#### `values/`
Helm chart values 파일
- `apps/` - 애플리케이션 서비스 values
- `infra/` - 인프라 서비스 values
- 각 서비스별 디렉토리 내에 환경별 파일 존재
  - `dev.yaml` - 개발 환경
  - `prd.yaml` - 프로덕션 환경

#### `manifests/`
Kubernetes 매니페스트 파일
- `vpa/` - VerticalPodAutoscaler 설정
- `traefik/` - Traefik 라우트 설정
- 기타 Kubernetes 리소스

## 🎯 새 애플리케이션 배포하기

새로운 오픈소스나 애플리케이션을 배포할 때:

1. **기존 패턴 참고**
   - `argocd/` 내의 유사한 앱 확인
   - `values/` 내의 유사한 values 파일 확인
   - 명명 규칙과 구조 파악

2. **필요한 파일 생성**
   - ArgoCD Application 매니페스트: `argocd/{env}/apps/{app-name}.yaml`
   - Helm values: `values/{apps|infra}/{service-name}/{env}.yaml`
   - 필요시 AppProject: `argocd/{env}/proj/{project-name}.yaml`

3. **Git 워크플로우**
   - 변경사항을 Git에 커밋 (커밋 메시지 컨벤션 준수)
   - 신규 앱/차트 추가 시 feature 브랜치 → PR → main 머지
   - 소규모 설정 변경은 main 직접 push 가능

## 🔧 Terraform & Terramate 워크플로우

### 핵심 도구
- **Terramate**: Terraform 코드 생성 및 오케스트레이션
- **Terraform**: 실제 인프라 프로비저닝

### 🚨 중요 규칙

#### 1. Terramate 생성 파일 절대 수정 금지
**절대 `_terramate_generated_*.tf` 파일을 직접 수정하지 마세요!**

이 파일들은 Terramate가 자동으로 생성합니다. 대신 Terramate 설정 파일(`.tm.hcl`)을 수정하세요.

#### 2. GitOps와의 차이
- **Kubernetes 리소스**: ArgoCD로 자동 배포 (kubectl apply 금지)
- **Terraform 리소스**: Terraform/Terramate로 수동 배포 (GitOps 대상 아님)

### Terraform 작업 프로세스

1. **스택 구조 확인**
```bash
terramate list
```

2. **Terramate 설정 수정**
스택별 `.tm.hcl` 파일 또는 `terramate.tm.hcl` 수정

3. **Terramate 코드 생성**
```bash
terramate generate
```

4. **Push → CI/CD 자동 적용**
```bash
git push  # CI/CD가 자동으로 plan + apply
```

## 💡 일반 지침

### 응답 스타일
- 간결하고 명확하게 답변
- 코드 예시와 함께 설명
- 한국어로 응답

### 파일 수정 시
- 기존 패턴과 일관성 유지
- YAML 문법 검증
- 환경별 차이점 고려 (dev/prd)

### 보안 고려사항
- 민감한 정보는 별도 Secret 관리
- 리소스 제한 설정 권장
- NetworkPolicy 고려

## 🌿 브랜치/커밋 컨벤션

### 브랜치 네이밍
`{type}/{scope}/{description}` 형식을 따른다.

| 유형 | 패턴 | 예시 |
|------|------|------|
| 신규 기능/차트 | `feat/{scope}/{desc}` | `feat/argo-workflows/add-chart` |
| 버그/설정 수정 | `fix/{scope}/{desc}` | `fix/stockroom-prd/db-env` |
| 유지보수 | `chore/{scope}/{desc}` | `chore/eks/upgrade-1.32` |
| 긴급 장애 | `hotfix/{desc}` | `hotfix/stockroom-prd-oom` |

### 커밋 메시지 형식
Conventional Commits: `{type}({scope}): {description}`

```
feat(argo-workflows): add helm chart for workflow orchestration
fix(stockroom/prd): correct DB_HOST environment variable
chore(eks): upgrade cluster version to 1.32
hotfix(stockroom/prd): increase memory limit to resolve OOM
```

**언어**: description(제목)은 영어, 동사 원형으로 시작. body(본문)는 필요 시 한국어 허용.

### 작업 유형별 판단 기준

| 변경 유형 | 브랜치 | PR |
|-----------|--------|-----|
| 단일 앱·단일 환경 소규모 수정 | `main` 직접 | 선택 |
| 신규 앱/차트/스택 추가 | `feat/*` | 필수 |
| 여러 앱/환경 동시 변경 | `feat/*` | 필수 |
| Terraform 인프라 변경 | `feat/*` 또는 `chore/*` | 필수 + plan 결과 첨부 |
| 긴급 장애 대응 | `main` 직접 | 사후 이슈 생성 |

### 커밋 품질
- 커밋 메시지에 **why(이유)**를 포함한다.
- values 파일에서 기본값과 다른 설정에는 주석으로 이유를 명시한다.
  - 예: `memory: 512Mi  # OOM으로 인해 증가 (2026-02-25)`

