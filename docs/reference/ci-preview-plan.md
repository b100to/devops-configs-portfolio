# CI: Terraform Preview (PR plan)

`.github/workflows/prewiew.yml` — PR 마다 변경된 스택의 `terraform plan` 을 돌리고
결과를 PR 코멘트로 남긴다. (`argocd/`·`manifests/` 만 바뀐 PR 은 대상 스택 0개)

## 잡 구성

| Job | 하는 일 |
|-----|---------|
| `Check formatting` | `terramate fmt --check`, `terraform fmt -check` |
| `Plan (dev)` / `Plan (prd)` | 변경 스택 탐지 → init → validate → plan → PR 코멘트 |

`Plan (*)` 은 `Check formatting` 을 기다리지 않는다(`needs` 없음). fmt 를 기다리면
plan 시작이 ~30초 늦어지고, 그만큼 auto-merge 레이스(아래)에 질 확률이 올라간다.

## ⚠️ auto-merge 레이스 — 이 워크플로 설계의 핵심 제약

`main` 브랜치 보호에 **required status check 가 없다.** 따라서
`gh pr merge --auto --squash` 는 PR 이 mergeable 해지는 즉시 머지한다 —
preview 잡이 아직 러너를 잡고 있는 동안에.

실제로 관측된 타임라인 (PR #347):

| 시각(UTC) | 이벤트 |
|-----------|--------|
| 05:58:42 | preview 워크플로 시작 |
| 05:58:54 | PR auto-merge 완료 (`main` 이 PR 변경분을 이미 포함) |
| 05:59:03 | `Sync with base branch` → `Merge made by the 'ort' strategy` |
| 05:59:06 | `terramate list --changed` → **빈 출력** |

Terramate 기본 change base 는 `origin/main` 이다. PR 이 먼저 머지되면 `origin/main`
이 PR 변경분을 이미 담고 있고, 그 위에 sync-merge 를 하면 diff 가 0 이 된다.
그러면 `if: steps.list.outputs.stdout` 이 걸린 init/validate/plan 이 전부 skip 되고
잡은 **30초 만에 초록불**로 끝난다 — preview 가 돌았는지 아닌지 구분이 안 된다.

### 대응 1 — change base 를 fork point 로 고정

`Resolve change base` 스텝이 **sync-merge 전에** `git merge-base origin/<base> HEAD`
를 계산하고, 모든 `--changed` 호출에 `-B <sha>` 로 넘긴다. squash 머지 커밋은 PR
head 의 조상이 아니므로 fork point 는 `main` 이 앞서가도 변하지 않는다.

```bash
# 레이스 상황 재현 (origin/main 이 이미 PR 변경분을 포함)
terramate list --tags=dev --changed              # (빈 출력)  ← 버그
terramate list --tags=dev --changed -B <forkpoint>
# stacks/acme/iam/authentik-aws-oidc/dev  ← 정상
```

### 대응 2 — 머지돼 버렸음을 PR 에 알림

`.github/scripts/publish-preview.js` 가 환경별로 sticky 코멘트 1개를 만들거나
갱신한다. 코멘트를 쓰는 시점에 PR 이 이미 merged 면 경고 문구를 덧붙이고
`core.warning()` 을 남긴다.

### 남은 한계

`-B` 로 plan 자체는 정상적으로 나오지만, PR 이 먼저 머지된 경우 그 plan 은
**사후 기록**이다. 머지 전에 plan 을 보고 판단하려면 `main` 브랜치 보호에
`Plan (dev)` / `Plan (prd)` 를 required status check 로 등록해야 한다.

```bash
gh api -X PATCH repos/AcmeCorp/devops-configs/branches/main/protection/required_status_checks \
  -f strict=false -f 'contexts[]=Check formatting' \
  -f 'contexts[]=Plan (dev)' -f 'contexts[]=Plan (prd)'
```

## 부수 메모

- `terramate-action@v2` 는 `use_wrapper: true`(기본값) 로 `terramate` 를 래퍼로
  깔아 준다. 래퍼가 stdout/stderr/exitcode 를 `$GITHUB_OUTPUT` 에 써 주므로
  `steps.<id>.outputs.stdout` 이 동작한다. 래퍼를 끄면 모든 `if:` 게이트가 죽는다.
- `.terraform.lock.hcl` 이 `.gitignore` 에 걸려 있어 provider 캐시 키
  (`hashFiles('**/.terraform.lock.hcl')`) 가 항상 빈 값이다. 캐시는
  `restore-keys` 로만 동작하고 provider 버전은 고정되지 않는다.
- plan 코멘트는 55,000자에서 잘린다(GitHub 코멘트 한도 65,536자). 전체 출력은
  Actions 로그 참고.
- **워크플로 파일명을 바꾸는 PR 은 그 PR 에서 워크플로가 안 돈다.** 실측:
  같은 브랜치에서 `prewiew.yml` 을 그대로 수정 → `pull_request` run 생성됨.
  `preview.yml` 로 rename → run 이 아예 안 생김(check-run 0개, 에러 표시도 없음).
  actionlint 통과, PR 은 MERGEABLE/CLEAN, `refs/pull/N/merge` 도 정상 생성.
  그래서 오타 `prewiew.yml` 을 그대로 둔다 — 이름을 고치면 정작 그 PR 의
  preview 가 조용히 안 도는, 여기서 고치려는 것과 똑같은 문제가 생긴다.
