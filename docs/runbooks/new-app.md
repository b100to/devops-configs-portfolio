# 새 앱 배포 런북

ArgoCD + Helm Chart를 사용해 새 애플리케이션을 Kubernetes에 배포하는 절차.

## 전제 조건

- ECR 레포지토리가 존재해야 한다
  - dev: `111111111111.dkr.ecr.ap-northeast-2.amazonaws.com/{repo-name}-dev`
  - prd: `222222222222.dkr.ecr.ap-northeast-2.amazonaws.com/{repo-name}-prod`
- 배포할 도메인(네임스페이스)의 AppProject가 이미 존재해야 한다
  - 신규 도메인이라면 [AppProject 생성](#신규-도메인팀-추가-시) 먼저 진행
- `devops-configs` 레포 write 권한

---

## 배포 절차

### Step 1. Values 파일 생성

`values/apps/{domain}/{app-name}/` 디렉토리를 만들고 환경별 values를 작성한다.

```bash
mkdir -p values/apps/{domain}/{app-name}
```

**`values/apps/{domain}/{app-name}/dev.yaml`**
```yaml
global:
  env: dev
  registry:
    accountId: "111111111111"
    region: "ap-northeast-2"

fullnameOverride: {app-name}

namespace:
  name: {domain}

image:
  repository: {ecr-repo-name}-dev
  tag: latest
  pullPolicy: IfNotPresent

serviceAccount:
  create: false
  name: app-{domain}
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::111111111111:role/eks-pod-identity-app-{domain}-v2

# replicaCount는 HPA가 관리하므로 주석 처리
# replicaCount: 1

priorityClassName: medium-high-priority

labels:
  env: dev

service:
  enabled: true
  type: ClusterIP
  port: 80
  targetPort: 8080  # 앱 포트에 맞게 수정

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    memory: 512Mi
```

prd 환경도 동일 구조로 작성한다. accountId `222222222222`, env `prd`, ECR repo 이름 `-prod` 접미사로 변경한다.

### Step 2. Application YAML 생성

**dev: `argocd/dev/apps/{domain}/{app-name}.yaml`**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {app-name}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd-image-updater.argoproj.io/image-list: app=111111111111.dkr.ecr.ap-northeast-2.amazonaws.com/{ecr-repo-name}-dev
    argocd-image-updater.argoproj.io/app.pull-secret: ext:/scripts/ecr.sh
    argocd-image-updater.argoproj.io/write-back-method: argocd
    argocd-image-updater.argoproj.io/app.update-strategy: newest-build
    argocd-image-updater.argoproj.io/app.platforms: linux/amd64
spec:
  project: {domain}
  source:
    repoURL: https://github.com/AcmeCorp/devops-configs.git
    targetRevision: main
    path: charts/app
    helm:
      valueFiles:
        - ../../values/apps/{domain}/{app-name}/dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: {domain}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # HPA가 replicas를 관리하므로 sync 제외
```

**prd: `argocd/prd/apps/{domain}/{app-name}.yaml`**

dev와 동일 구조. 변경 사항:
- `image-list` annotation의 account ID → `222222222222`, ECR repo 이름 → `-prod`
- `valueFiles` 경로 → `prd.yaml`

### Step 3. Git Push

```bash
git add argocd/ values/
git commit -m "feat({app-name}): add {env} deployment"
git push
```

### Step 4. ArgoCD 싱크 확인

ArgoCD는 Git push 후 자동으로 감지하고 배포한다. 완료까지 보통 1-3분 소요.

```bash
# 앱 상태 확인
argocd app get {app-name}

# Synced + Healthy 될 때까지 watch
argocd app get {app-name} -o json | jq '{sync: .status.sync.status, health: .status.health.status}'

# OutOfSync 상태라면 수동 트리거
argocd app sync {app-name}

# 배포된 pod 확인
kubectl get pods -n {domain} -l app.kubernetes.io/name={app-name}
```

---

## dev/prd 환경별 차이점

| 항목 | dev | prd |
|------|-----|-----|
| AWS Account ID | `111111111111` | `222222222222` |
| ECR repo 접미사 | `-dev` | `-prod` |
| values 파일 | `dev.yaml` | `prd.yaml` |
| ArgoCD cluster | `acme-dev` | `acme-prd` |
| `global.env` | `dev` | `prd` |
| IAM role ARN | `iam::111111111111:role/...` | `iam::222222222222:role/...` |

---

## Image Updater 설정

모든 앱은 ArgoCD Image Updater를 통해 ECR 이미지를 자동으로 업데이트한다.

**필수 annotation 4개:**

```yaml
annotations:
  # 이미지 소스 (alias=app 고정)
  argocd-image-updater.argoproj.io/image-list: app={account-id}.dkr.ecr.ap-northeast-2.amazonaws.com/{repo-name}

  # ECR 인증 스크립트 (클러스터 내 스크립트 사용)
  argocd-image-updater.argoproj.io/app.pull-secret: ext:/scripts/ecr.sh

  # 이미지 태그를 ArgoCD Application 파라미터로 저장 (Git write-back 없음)
  argocd-image-updater.argoproj.io/write-back-method: argocd

  # 가장 최근 빌드된 이미지를 사용 (semver 아님)
  argocd-image-updater.argoproj.io/app.update-strategy: newest-build

  # amd64 아키텍처만 대상
  argocd-image-updater.argoproj.io/app.platforms: linux/amd64
```

Image Updater가 새 이미지를 감지하면 자동으로 배포한다. 수동으로 특정 태그를 강제 배포하려면:

```bash
argocd app set {app-name} --helm-set image.tag={tag}
argocd app sync {app-name}
```

---

## 신규 도메인(팀) 추가 시

새 도메인(예: `platform`)을 추가하려면 AppProject를 먼저 생성한다.

**`argocd/dev/apps/{domain}/_project.yaml`**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: {domain}
  namespace: argocd
spec:
  description: {domain}
  sourceRepos:
    - "*"
  destinations:
    - namespace: {domain}
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace
  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"
```

dev/prd 양쪽 모두 동일하게 생성한다.

AppProject를 git push하면 ArgoCD가 감지하여 자동 생성한다. Project가 준비된 후 앱 배포 절차를 진행한다.

```bash
# AppProject 생성 확인
argocd proj get {domain}
```

---

## 트러블슈팅

**pod가 뜨지 않을 때**
```bash
kubectl describe pod -n {domain} {pod-name}
kubectl logs -n {domain} {pod-name} --previous
```

**이미지 pull 실패 (ECR)**
- ECR 레포 이름과 values의 `image.repository` 일치 여부 확인
- Image Updater log 확인: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater`

**ArgoCD sync 실패**
```bash
argocd app get {app-name}  # 에러 메시지 확인
argocd app sync {app-name} --force
```
