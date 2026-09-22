# Plane 배포 Runbook

Plane CE(Community Edition) K8s 배포 및 초기 설정 가이드.

## 목차

1. [아키텍처](#아키텍처)
2. [신규 환경 배포](#신규-환경-배포)
3. [Google 소셜 로그인 설정](#google-소셜-로그인-설정)
4. [SES SMTP 설정](#ses-smtp-설정)
5. [초대 기반 온보딩 흐름](#초대-기반-온보딩-흐름)
6. [트러블슈팅](#트러블슈팅)

---

## 아키텍처

```
ALB → Traefik → Plane (tools namespace)
                 ├── web-wl       (Next.js 프론트엔드)
                 ├── api-wl       (Django REST API)
                 ├── space-wl     (공개 페이지)
                 ├── admin-wl     (god-mode 관리자 UI)
                 ├── live-wl      (실시간 협업)
                 ├── worker-wl    (Celery 비동기 태스크)
                 ├── beat-worker-wl (Celery 스케줄러)
                 ├── pgdb-wl      (PostgreSQL)
                 ├── redis-wl     (Redis)
                 ├── rabbitmq-wl  (RabbitMQ)
                 └── minio-wl     (S3 호환 오브젝트 스토리지)
```

**관련 파일:**
| 파일 | 역할 |
|------|------|
| `argocd/{env}/apps/tools/plane.yaml` | ArgoCD Application 정의 |
| `values/infra/plane/{env}.yaml` | Helm values |
| `manifests/plane/{env}/app-secrets.yaml` | 커스텀 시크릿 (URL 오버라이드, OAuth 자격증명) |
| `manifests/traefik/{env}/tools.yaml` | Traefik IngressRoute |

---

## 신규 환경 배포

### 1. Secrets Manager에 시크릿 추가

`eks/acme-main-v2-{env}` SM 시크릿에 아래 키 추가:

```json
{
  "plane_google_client_id": "<Google OAuth Client ID>",
  "plane_google_client_secret": "<Google OAuth Client Secret>"
}
```

### 2. ExternalSecret 생성

`manifests/plane/{env}/external-secret.yaml` 생성 (아래 참고).

### 3. ArgoCD Application 등록

`argocd/{env}/apps/tools/plane.yaml` 생성.

### 4. Traefik IngressRoute 추가

`manifests/traefik/{env}/tools.yaml`에 plane 라우트 추가:
- `/god-mode` → admin-wl (port 8000)
- `/api`, `/auth`, `/spaces` → api-wl (port 8000)
- `/` (catch-all) → web-wl (port 3000)
- middleware: `plane-https-header` (X-Forwarded-Proto: https 주입 필수)

### 5. ArgoCD 싱크 후 확인

```bash
argocd app get plane-{env} -o json | jq '{sync: .status.sync.status, health: .status.health.status}'
kubectl get pods -n tools | grep plane
```

---

## Google 소셜 로그인 설정

### 배경

Plane CE는 `configure_instance` 관리 커맨드로 초기 설정을 수행함. 이 커맨드는 **Pod 최초 기동 시 한 번만** 실행됨.

- `GOOGLE_CLIENT_ID` 환경변수가 설정되어 있으면 → DB에 `IS_GOOGLE_ENABLED=1` 자동 생성
- 환경변수가 없으면 → `IS_GOOGLE_ENABLED=0` (기본값), 이후 수동 설정 필요

**따라서: 신규 배포 시 SM에 값을 넣고 배포하면 자동으로 구성됨.**

### 코드 위치

```
/code/plane/authentication/provider/oauth/google.py

redirect_uri = f"""{"https" if request.is_secure() else "http"}://{request.get_host()}/auth/google/callback/"""
```

`SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")` 설정 때문에 Traefik이 `X-Forwarded-Proto: https` 헤더를 주입하면 `request.is_secure() = True` 반환.

### 설정 절차 (신규 배포)

1. **Google Cloud Console** → OAuth 2.0 클라이언트 생성
   - 유형: 웹 애플리케이션
   - **승인된 JavaScript 원본**: `https://plane.{env}.acme.example`
   - **승인된 리디렉션 URI**: `https://plane.{env}.acme.example/auth/google/callback/`
     ⚠️ `/auth/google/` 이 아닌 `/auth/google/callback/` (trailing slash 포함 필수)

2. **SM에 저장** (`eks/acme-main-v2-{env}`):
   ```json
   {
     "plane_google_client_id": "...",
     "plane_google_client_secret": "..."
   }
   ```

3. **ExternalSecret 확인** → `plane-app-secrets-custom`에 `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` 키 포함

4. **Plane 배포** → `configure_instance` 자동 실행 → `IS_GOOGLE_ENABLED=1` 자동 설정

### 기존 설치에서 Google 활성화 (DB에 값이 이미 있는 경우)

`configure_instance`는 이미 존재하는 DB 항목을 건드리지 않음. 아래 방법으로 수동 활성화:

```bash
kubectl exec -n tools <api-pod> -- python manage.py shell -c "
from plane.license.models import InstanceConfiguration
from plane.license.utils.encryption import encrypt_data
import os

# Google Client ID 설정
obj, _ = InstanceConfiguration.objects.get_or_create(key='GOOGLE_CLIENT_ID')
obj.value = '<client_id>'
obj.is_encrypted = False
obj.save()

# Google Client Secret 설정 (Fernet 암호화 필수)
obj, _ = InstanceConfiguration.objects.get_or_create(key='GOOGLE_CLIENT_SECRET')
obj.value = encrypt_data('<client_secret>')
obj.is_encrypted = True
obj.save()

# Google 활성화 플래그
obj, _ = InstanceConfiguration.objects.get_or_create(key='IS_GOOGLE_ENABLED')
obj.value = '1'
obj.is_encrypted = False
obj.save()

# 캐시 초기화
from django.core.cache import cache
cache.clear()
print('Done')
"
```

---

## SES SMTP 설정

### Terraform 스택

`stacks/acme/ses/{env}/` — SES 도메인 인증 + IAM SMTP 사용자 생성 + SM 저장.

SES 적용 후 SM에 생성되는 시크릿: `ses/smtp-credentials-{env}`

```json
{
  "smtp_host": "email-smtp.ap-northeast-2.amazonaws.com",
  "smtp_port": "587",
  "smtp_username": "<IAM Access Key ID>",
  "smtp_password": "<SES SMTP Password>",
  "from_email": "no-reply@{env}.acme.example"
}
```

### god-mode에서 SMTP 설정

1. `https://plane.{env}.acme.example/god-mode/` 접속
2. **Email** 메뉴
3. SM 시크릿 값을 복사하여 입력:
   - **Email Host**: `email-smtp.ap-northeast-2.amazonaws.com`
   - **Email Port**: `587`
   - **STARTTLS**: 활성화
   - **Username**: SM의 `smtp_username`
   - **Password**: SM의 `smtp_password`
   - **From Email**: SM의 `from_email`

### SES Production Access

기본 SES는 Sandbox 상태 → 인증된 이메일만 수신 가능.
외부 이메일(회사 밖)로 초대를 보내려면 **Production Access** 신청 필요:
- AWS Console → SES → Account Dashboard → Request Production Access
- 예상 발송량, 바운스/컴플레인 처리 방법 기재

---

## 초대 기반 온보딩 흐름

외부 사용자(다른 회사) 초대 절차:

1. **Plane god-mode에서 이메일 설정** (위 SMTP 설정 참고)
2. **워크스페이스 관리자**가 구성원 초대 → 초대 이메일 발송
3. **외부 사용자**가 이메일 링크 클릭 → 이메일/비밀번호로 회원가입 또는 Google 로그인
4. 회원가입 완료 → 워크스페이스 자동 참여

> **Google 소셜 로그인**: 어떤 Google 계정으로도 가입 가능 (acme.example 도메인 제한 없음).
> 단, 초대 이메일로 들어온 사용자만 워크스페이스에 접근 가능.

---

## 트러블슈팅

### WEB_URL이 `http://plane.example.com`으로 표시됨

차트 ConfigMap이 `WEB_URL=http://plane.example.com`을 하드코딩함. `env.web_url` values 설정은 CORS만 추가할 뿐 WEB_URL을 오버라이드하지 않음.

**해결**: `plane-app-secrets-custom` Secret에 `WEB_URL: "https://..."` 추가.
Secret의 envFrom이 ConfigMap보다 나중에 로드되어 오버라이드됨.

### 기존 PVC가 삭제된 EBS 볼륨을 참조함

오래된 PVC(EBS 삭제 후)를 가진 StatefulSet Pod를 재기동해도 해결 안 됨.

**해결**: Pod 삭제 → PVC 삭제 → StatefulSet이 새 PVC 자동 생성.

### Migrate Job 실패

`plane-api-migrate-*` Job이 DB 준비 전 실행되어 실패.

**해결**: 실패한 Job 삭제 → ArgoCD가 재생성 → DB 준비 후 마이그레이션 성공.

### Google 로그인 `redirect_uri_mismatch`

Plane이 Google로 전송하는 redirect_uri:
```
https://{WEB_URL}/auth/google/callback/
```

Google Cloud Console 등록 필요:
- ❌ `https://plane.dev.acme.example/auth/google/` (잘못된 경로)
- ✅ `https://plane.dev.acme.example/auth/google/callback/` (올바른 경로)

### "Google not configured" 에러

`IS_GOOGLE_ENABLED` DB 항목이 없거나 `"0"`인 경우.
위 [기존 설치에서 Google 활성화](#기존-설치에서-google-활성화-db에-값이-이미-있는-경우) 절차 참고.
