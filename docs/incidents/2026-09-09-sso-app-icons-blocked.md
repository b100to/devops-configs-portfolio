# SSO 포털 앱 아이콘 미표시 + authentik 블루프린트 6개월 무응답

## 개요

| 항목 | 내용 |
|------|------|
| 리포트 | 2026-09-09 (사용자 제보: `sso.acme.example/if/user/#/library` 아이콘 안 보임) |
| 영향 범위 | prd SSO 포털 앱 타일 아이콘 (인증 기능 자체는 정상) |
| 근본 원인 1 | 앱 아이콘을 외부 CDN(`api.iconify.design`)에 핫링크 |
| 근본 원인 2 | `meta_launch_url: hide_application` 로 인해 `aws-cli-oidc-application.yaml` 블루프린트가 2026-03-05부터 apply 실패 |
| 조치 | 아이콘 self-host(PR #355) + 블루프린트 값 정정(PR #356) |
| 서비스 중단 | 없음 (로그인·인가 정상, 표시 문제만) |

## 증상

- Chrome 에서 SSO 포털 앱 타일 아이콘이 전부 안 보임
- 같은 계정·같은 URL을 Zen 브라우저로 열면 **정상 표시** → 클라이언트 측 차단으로 판명

## 진단

### 1. 서버 측 차단 여부 — 무죄

```bash
curl -sI https://sso.acme.example/if/user/
# Content-Security-Policy 헤더 없음
curl -s https://sso.acme.example/if/user/ | grep -i Content-Security-Policy
# meta 태그도 없음
```

authentik / Traefik 어디에도 CSP 설정 없음. `values`, `manifests` 전체 grep에서도 CSP 항목 없음.

### 2. 네트워크·DNS — 무죄

| 체크 | 결과 |
|------|------|
| `curl` (브라우저 UA + Referer + Sec-Fetch 헤더) | `200 image/svg+xml` |
| 시스템 DNS | 정상 해석 |
| DoH (Cloudflare / Google) | 정상 해석 |
| `/etc/hosts` 차단 항목 | 없음 |
| 로컬 차단 앱(AdGuard, Little Snitch 등) | 미설치 |

### 3. 브라우저 — 범인

동일 네트워크·동일 시각에 Chrome은 실패, Zen은 성공.
Chrome 확장 프로그램(광고·트래커 차단) 필터 리스트가 서드파티 CDN인
`api.iconify.design` 을 차단한 것으로 확인.

> 확장 프로그램 필터 리스트는 사용자 개입 없이 자동 갱신된다.
> 즉 **레포 변경 없이도 어느 날 갑자기 깨질 수 있는 구조**였다.
> 레포 측 아이콘 URL 마지막 변경은 2026-07-22(`62ba707d`), authentik 차트는 2026-02-24 이후 고정.

### 4. 부수 발견 — 블루프린트가 6개월간 실패 중

아이콘 값을 교체하고 배포했는데 **16개 앱 중 15개만 반영**됐다. `aws-cli` 만 옛 URL 유지.

```sql
select path, status from authentik_blueprints_blueprintinstance where status <> 'successful';
-- mounted/cm-authentik-blueprints/aws-cli-oidc-application.yaml | error
-- mounted/cm-authentik-blueprints/google-oauth-source.yaml      | error
```

DB의 `aws-cli` launch URL이 2026-03-05 커밋 `cf1b5a43` 이전 값(docs URL)에 멈춰 있었다.
그 커밋이 넣은 `meta_launch_url: hide_application` 은 authentik이 URL로 검증하는 필드에
스킴 없는 문자열을 넣은 것이라 검증 실패 → **해당 블루프린트 전체가 6개월간 apply 안 됨**.

즉 그때 의도한 "AWS CLI 앱 숨기기"는 한 번도 적용된 적이 없다.

## 근본 원인

### 원인 1 — 외부 CDN 핫링크

```
브라우저 → api.iconify.design (Cloudflare)
```

아이콘이 사용자 브라우저에서 직접 서드파티로 요청됨. 확장 프로그램·DNS 필터·CDN 장애
어느 하나만 걸려도 전부 깨지고, 우리 쪽 로그에는 아무 흔적도 안 남는다.

추가로 이미 조용히 깨져 있던 것 2개를 함께 발견:

| 앱 | 문제 |
|----|------|
| Outline Wiki | `?color=%FFFFFF` — percent-encoding 오타 (`%23FFFFFF` 여야 함) |
| Wiki (Google Sites) | `simple-icons:googlesites` 가 iconify에서 삭제됨 → 404 |

### 원인 2 — authentik의 launch URL 검증 규칙

authentik 공식 문서(`add-secure-apps/applications/index.md`):

> Only applications whose launch URL starts with `http://` or `https://` or are relative URLs
> are shown on the users' **My applications** page. This can also be used to hide applications
> ... by setting the _Launch URL_ to `blank://blank`.

| 값 | 결과 |
|----|------|
| `https://...` | 타일 표시 |
| 빈 값 | authentik이 provider 기준으로 URL 추측 → 다시 노출될 수 있음 |
| `blank://blank` | 숨김 (공식 관용구) |
| `hide_application` | 검증 실패 → 블루프린트 전체 apply 실패 |

## 조치

### PR #355 — 아이콘 self-host

| 파일 | 변경 |
|------|------|
| `manifests/authentik/prd/app-icons.yaml` | 신규. SVG 11개를 ConfigMap `authentik-app-icons` 로 고정 |
| `values/infra/authentik/prd.yaml` | server pod에 `/media/public/icons` read-only 마운트 |
| `manifests/authentik/prd/blueprints.yaml` | icon 값 → `/media/public/icons/<name>.svg` (14곳) |

동작 원리:

- authentik `settings.py`: `MEDIA_URL = "/media/"`, `MEDIA_ROOT = storage.media.file.path` (기본 `/media`)
- go 서버 바이너리가 `/media` prefix를 파일 서버로 서빙
- `ApplicationSerializer` 는 `meta_icon` 값이 `/` 또는 `http` 로 시작하면 그대로 반환 → 절대경로 사용 가능

Google Sites 아이콘은 삭제된 `simple-icons:googlesites` 대신
`thesvg-color:google-sites-2026` 컬러 로고로 대체.

### PR #356 — 블루프린트 값 정정

`meta_launch_url: hide_application` → `blank://blank`.
2026-03-05에 의도했던 "AWS CLI 앱 숨기기"가 이제 실제로 적용된다.

## 검증

```bash
# 아이콘 서빙
curl -I https://sso.acme.example/media/public/icons/airflow.svg   # 200 image/svg+xml

# ArgoCD
kubectl --context=acme-prd get application authentik -n argocd \
  -o jsonpath='{.status.sync.status} {.status.health.status}'   # Synced Healthy

# 블루프린트 apply 상태 (실패한 것만)
select path, status from authentik_blueprints_blueprintinstance where status <> 'successful';

# 앱별 아이콘 값
select slug, meta_icon from authentik_core_application order by slug;
```

## 남은 이슈

- `google-oauth-source.yaml` 블루프린트도 `error` 상태.
  원인은 `KeyOf: failed to find entry with id of google-source-authentication-mfa-flow`.
  별건이므로 이 문서에서는 다루지 않음.
- authentik 블루프린트는 **apply 실패해도 알림이 없다.** 이번처럼 6개월간 무응답이어도
  아무도 모른다. 상태 감시(모니터링 또는 정기 점검) 검토 필요.
- `kubecost-application.yaml` 은 `successful` 로 표시되지만 마지막 apply가 **2026-03-05**이고,
  그 뒤 2026-06-08에 dev kubecost가 철거되면서 Application이 삭제됐다.
  즉 **이 파일을 한 글자라도 고치면 철거된 dev kubecost 앱이 되살아난다.**
  prd kubecost SSO는 Application이 아니라 oauth2provider(`client_id: kubecost`)로 동작하므로
  현재 동작에는 영향 없음. 정리하려면 provider 사용처 확인 후 별도 PR.

## 후속 발견 (2026-09-09, PR #357/#358)

`argocd-cli` 타일 숨김 작업(PR #357) 중 같은 함정을 한 번 더 밟았다.

- 같은 파일(`non-dev-access-control.yaml`)의 **주석 한 줄**을 고쳤더니 해시가 바뀌어 재적용됨
- 그 결과 `error` 로 전환 — 원인은 존재하지 않는 앱 참조 2건
  (`kubecost`: 2026-06-08 철거, `kubecost-prd`: 애초에 생성된 적 없음)
- 즉 이 블루프린트는 **2026-06-08부터 이미 깨져 있었고**, 내용이 안 바뀌어 재적용이 안 된 덕에
  `successful` 표시만 남아 있었다. PR #358에서 죽은 바인딩 2건 제거

교훈: **블루프린트의 `successful` 은 "마지막 apply 시점에 성공했다"는 뜻이지
"지금 코드가 유효하다"는 뜻이 아니다.** 참조 대상이 나중에 삭제돼도 상태는 그대로 남는다.

## 배운 것

1. **외부 CDN 핫링크는 우리가 통제할 수 없는 실패 지점**이다. 사용자 브라우저 확장이
   조용히 업데이트되면 레포 변경 0줄로도 깨진다. 아이콘·폰트 같은 정적 자산은 self-host가 안전하다.
   (공급망 보안 관점에서도 유리)
2. **"브라우저 A는 되고 B는 안 된다"는 서버 무죄의 강력한 증거**다. 진단 순서를
   서버 → 네트워크/DNS → 브라우저로 좁히면 빠르게 격리된다.
3. **GitOps는 "커밋했다 = 반영됐다"를 보장하지 않는다.** authentik 블루프린트는
   ArgoCD가 ConfigMap을 Synced 로 표시해도, authentik 워커가 적용에 실패하면 그대로 끝이다.
   ArgoCD `Synced + Healthy` 는 "매니페스트가 클러스터에 있다"까지만 증명한다.
   실제 반영은 대상 시스템의 상태(여기서는 `blueprintinstance.status`)로 확인해야 한다.
4. 값이 사람에게 읽히기 좋다고 시스템이 알아듣는 건 아니다. `hide_application` 은
   의도는 명확했지만 authentik에겐 그냥 잘못된 URL이었다.
