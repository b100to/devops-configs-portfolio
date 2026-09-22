#!/usr/bin/env bash
set -euo pipefail

# acme — Acme developer CLI
#
# 개발자가 사내 인프라에 쉽게 접근하도록 돕는 헬퍼 CLI.
# 현재 제공 기능:
#   pf    MySQL 프록시 port-forward (dev/prd)
#   ssh   내부 서버에 SSM 으로 접속 (키리스, 포트 미개방, 감사로깅)
#
# 인증은 kubeconfig 의 aws-oidc credential_process 가 id_token 을 무음 자동 갱신하므로
# 평소엔 별도 로그인이 필요 없다. refresh_token 까지 만료된 경우에만
# `aws-oidc login <env>` 안내를 출력한다 (브라우저 자동 팝업 없음).

PROG="acme"
STATE_DIR="${ACME_STATE_DIR:-$HOME/.cache/acme/pf}"
REGION="${AWS_REGION:-ap-northeast-2}"

# --- port-forward 매핑 테이블 ---------------------------------------------
# key: "<env>/<target>"  value: "<context> <svc> <localPort> <remotePort>"
pf_spec() {
  case "$1" in
    dev/acmemall)         echo "acme-dev  mall-mysql-service           13307 3306" ;;
    dev/service)            echo "acme-dev  venue-mysql-service        13306 3306" ;;
    prd/acmemall)         echo "acme-prd  mall-mysql-service           23307 3306" ;;
    prd/service)            echo "acme-prd  venue-mysql-service        24306 4306" ;;
    prd/acme)             echo "acme-prd  acme-mysql-service         25308 3306" ;;
    prd/airflow)            echo "acme-prd  airflow-pg-service           25432 5432" ;;
    prd/beacon)              echo "acme-prd  beacon-pg-service             25433 5432" ;;
    # 매일 갱신되는 당일 클론(stable CNAME)
    prd/acmemall-clone)   echo "acme-prd  mall-clone-mysql-service     25307 3306" ;;
    prd/service-clone)      echo "acme-prd  service-clone-mysql-service  25306 3306" ;;
    *) return 1 ;;
  esac
}

# --- SSM 접속 타겟 매핑 테이블 --------------------------------------------
# key: "<target>"  value: "<instance-id> <env> <login-user>"
# 새 내부 서버 추가 시 여기 한 줄만 추가하면 됨.
ssh_spec() {
  case "$1" in
    blog) echo "i-0000000000000001 prd bitnami" ;;
    *) return 1 ;;
  esac
}

# ──────────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
${PROG} — Acme developer CLI

Usage:
  ${PROG} pf <dev|prd> [target]   DB 프록시 port-forward (기본 target: all)
  ${PROG} pf --status             떠있는 터널 목록
  ${PROG} pf --stop               모든 터널 종료
  ${PROG} ssh <target> [--fast]   내부 서버에 SSM 접속 (--fast: SSH-over-SSM, 빠름)
  ${PROG} ssh-key-register <target>   내 공개키를 SSM 으로 등록 (--fast 사용 전 1회)
  ${PROG} -h | --help

Targets:
  pf  dev:  acmemall | service | all
  pf  prd:  acmemall | service | acme | airflow | beacon | all
            | acmemall-clone | service-clone
  ssh:      blog

Examples:
  ${PROG} pf dev               # dev acmemall + service 둘 다
  ${PROG} pf prd acmemall    # prd acmemall(몰) 만
  ${PROG} pf prd service-clone # prd service 당일 클론 (매일 자동 갱신)
  ${PROG} pf prd airflow       # airflow 메타 DB (postgres)
  ${PROG} pf --status
  ${PROG} ssh blog             # 키리스 SSM 접속 (누구나 바로)
  ${PROG} ssh-key-register blog && ${PROG} ssh blog --fast   # 빠른 SSH 접속

연결 정보 (Host 127.0.0.1):
  dev  acmemall=13307  service=13306
  prd  acmemall=23307  service=24306  acme=25308
  prd  airflow=25432(pg)  beacon=25433(pg)
  prd  service-clone=25306  acmemall-clone=25307
  ※ 프록시 타겟은 모두 *-db.acme.example CNAME — RDS 변경 시 Route53만 갱신
  ※ acme / beacon 는 현재 휴면(인스턴스 0) — 기동 시 사용 가능
  ※ 클론은 매일 생성되는 당일 복제본에 자동 연결됨

ssh 접속은 SSH 키·22 포트 없이 SSM 채널만 사용하며, 접속 이력이 CloudWatch 에 감사 로깅됩니다.
EOF
}

die()  { echo "❌ $*" >&2; exit 1; }
info() { echo "→  $*"; }

# kubectl 존재 확인
need_kubectl() {
  command -v kubectl >/dev/null 2>&1 || die "kubectl 이 PATH 에 없습니다."
}

# --- SSM 접속 헬퍼 --------------------------------------------------------
need_aws() {
  command -v aws >/dev/null 2>&1 || die "aws CLI 가 PATH 에 없습니다."
}

need_ssm_plugin() {
  command -v session-manager-plugin >/dev/null 2>&1 \
    || die "session-manager-plugin 없음. 설치: brew install --cask session-manager-plugin"
}

# AWS 인증 확인. 실패 시 aws-oidc login 안내.
aws_preflight() {
  local env="$1"
  aws sts get-caller-identity --profile "$env" >/dev/null 2>&1 \
    || die "AWS 인증 실패(${env}). 먼저 실행: aws-oidc login ${env}"
}

# 기본 공개키 경로 선택 (ed25519 → rsa → ecdsa 순)
default_pubkey() {
  local k
  for k in id_ed25519 id_rsa id_ecdsa; do
    [[ -f "$HOME/.ssh/${k}.pub" ]] && { echo "$HOME/.ssh/${k}.pub"; return 0; }
  done
  return 1
}

cmd_ssh() {
  local fast=0 target=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fast) fast=1 ;;
      -h|--help) usage; exit 0 ;;
      -*) die "알 수 없는 옵션: $1" ;;
      *) target="$1" ;;
    esac
    shift
  done
  [[ -n "$target" ]] || { usage; exit 1; }

  local spec iid env user
  spec="$(ssh_spec "$target")" || die "알 수 없는 타겟: ${target} (사용 가능: blog)"
  read -r iid env user <<<"$spec"

  need_aws; need_ssm_plugin; aws_preflight "$env"

  if [[ "$fast" == 1 ]]; then
    command -v ssh >/dev/null 2>&1 || die "ssh 가 PATH 에 없습니다."
    local pub idfile
    pub="$(default_pubkey)" || die "SSH 키 없음. 'ssh-keygen -t ed25519' 후 '${PROG} ssh-key-register ${target}' 실행."
    idfile="${pub%.pub}"
    info "⚡ SSH over SSM: ${target} (${iid}) — ${idfile##*/} 사용"
    exec ssh -i "$idfile" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new \
      -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --profile ${env} --region ${REGION}" \
      "${user}@${iid}"
  else
    info "SSM 세션: ${target} (${iid}) — 더 빠른 접속은 '${PROG} ssh ${target} --fast'"
    exec aws ssm start-session --target "$iid" --profile "$env" --region "$REGION"
  fi
}

cmd_ssh_key_register() {
  local target="${1:-}"
  case "$target" in ""|-h|--help) die "사용법: ${PROG} ssh-key-register <target>" ;; esac

  local spec iid env user
  spec="$(ssh_spec "$target")" || die "알 수 없는 타겟: ${target} (사용 가능: blog)"
  read -r iid env user <<<"$spec"

  need_aws; aws_preflight "$env"

  local pub key
  pub="$(default_pubkey)" || die "공개키 없음. 'ssh-keygen -t ed25519' 로 생성 후 다시 실행."
  key="$(cat "$pub")"
  info "공개키 등록(${pub##*/}) → ${target}:${user} (SSM send-command, 개인키는 전송 안 됨)"

  local cid
  cid="$(aws ssm send-command --profile "$env" --region "$REGION" \
    --instance-ids "$iid" --document-name AWS-RunShellScript \
    --parameters commands="[\"install -d -m 700 -o ${user} -g ${user} /home/${user}/.ssh\",\"touch /home/${user}/.ssh/authorized_keys\",\"grep -qF '${key}' /home/${user}/.ssh/authorized_keys || echo '${key}' >> /home/${user}/.ssh/authorized_keys\",\"chmod 600 /home/${user}/.ssh/authorized_keys\",\"chown ${user}:${user} /home/${user}/.ssh/authorized_keys\",\"echo REGISTERED\"]" \
    --query 'Command.CommandId' --output text 2>/dev/null)" || die "send-command 실패 (권한/인증 확인)"

  local st
  for _ in $(seq 1 12); do
    sleep 2
    st="$(aws ssm get-command-invocation --profile "$env" --region "$REGION" \
      --command-id "$cid" --instance-id "$iid" --query 'Status' --output text 2>/dev/null || echo Pending)"
    case "$st" in
      Success) info "✓ 등록 완료. 이제 '${PROG} ssh ${target} --fast' 사용 가능."; return 0 ;;
      Failed|Cancelled|TimedOut) die "등록 실패: ${st} (CommandId: ${cid})" ;;
    esac
  done
  die "등록 상태 확인 timeout (CommandId: ${cid})"
}

# context 존재 + 인증 확인. 실패 시 aws-oidc login 안내.
preflight() {
  local env="$1" ctx="$2"
  kubectl config get-contexts -o name 2>/dev/null | grep -qx "$ctx" \
    || die "kubectl context '$ctx' 없음. 'aws eks update-kubeconfig --name acme-main-v2-${env} --alias ${ctx} --region ap-northeast-2' 먼저."
  if ! kubectl --context="$ctx" -n default get svc >/dev/null 2>&1; then
    die "클러스터 접근 실패. 토큰 만료라면 먼저 실행: aws-oidc login ${env}"
  fi
}

# 단일 타겟 port-forward 기동 (백그라운드 + pidfile)
pf_start_one() {
  local env="$1" target="$2"
  local spec ctx svc lport rport
  spec="$(pf_spec "${env}/${target}")" || die "알 수 없는 타겟: ${target} (mall|service)"
  read -r ctx svc lport rport <<<"$spec"

  mkdir -p "$STATE_DIR"
  local pidfile="$STATE_DIR/${env}-${target}.pid"

  if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    info "이미 실행 중: ${env}/${target} → 127.0.0.1:${lport}"
    return 0
  fi

  # 로컬 포트 선점 여부 확인
  if lsof -nP -iTCP:"${lport}" -sTCP:LISTEN >/dev/null 2>&1; then
    die "로컬 포트 ${lport} 이 이미 사용 중입니다 (${env}/${target})."
  fi

  local logfile="$STATE_DIR/${env}-${target}.log"
  # nohup + </dev/null + disown 으로 터미널과 완전히 분리 → 터미널 닫아도 터널 유지
  nohup kubectl --context="$ctx" -n default port-forward "svc/${svc}" "${lport}:${rport}" \
    </dev/null >"$logfile" 2>&1 &
  local pid=$!
  disown "$pid" 2>/dev/null || true
  echo "$pid" >"$pidfile"

  # 기동 확인 (최대 ~3s)
  for _ in 1 2 3 4 5 6; do
    grep -q "Forwarding from" "$logfile" 2>/dev/null && break
    kill -0 "$pid" 2>/dev/null || { cat "$logfile" >&2; rm -f "$pidfile"; die "port-forward 기동 실패: ${env}/${target}"; }
    sleep 0.5
  done
  info "✓ ${env}/${target}  →  127.0.0.1:${lport}  (pid ${pid})"
}

cmd_pf() {
  need_kubectl
  local arg="${1:-}"
  case "$arg" in
    ""|-h|--help) usage; exit 0 ;;
    --status) pf_status; exit 0 ;;
    --stop)   pf_stop;   exit 0 ;;
  esac

  local env="$arg" target="${2:-all}"
  [[ "$env" == "dev" || "$env" == "prd" ]] || die "env 는 dev 또는 prd (입력: ${env})"

  local ctx
  ctx="$([[ "$env" == "dev" ]] && echo acme-dev || echo acme-prd)"
  preflight "$env" "$ctx"

  local targets
  if [[ "$target" == "all" ]]; then
    if [[ "$env" == "dev" ]]; then
      targets="acmemall service"
    else
      # prd 전체 — 클론/airflow 포함. acme/beacon 는 휴면이지만 터널 자체는 기동됨
      targets="acmemall service acme airflow beacon acmemall-clone service-clone"
    fi
  else
    targets="$target"
  fi

  for t in $targets; do pf_start_one "$env" "$t"; done

  echo
  info "터널 유지 중. 종료: ${PROG} pf --stop   상태: ${PROG} pf --status"
  [[ "$env" == "prd" ]] && echo "⚠️  prd 운영 DB — 조회 위주로 사용하세요."
}

pf_status() {
  mkdir -p "$STATE_DIR"
  local found=0
  for pidfile in "$STATE_DIR"/*.pid; do
    [[ -e "$pidfile" ]] || continue
    local name pid
    name="$(basename "$pidfile" .pid)"
    pid="$(cat "$pidfile")"
    if kill -0 "$pid" 2>/dev/null; then
      local spec lport
      spec="$(pf_spec "${name/-//}")" || spec=""
      lport="$(awk '{print $3}' <<<"$spec")"
      echo "● ${name}  pid=${pid}  127.0.0.1:${lport:-?}"
      found=1
    else
      rm -f "$pidfile"
    fi
  done
  [[ "$found" == 0 ]] && echo "(실행 중인 터널 없음)"
}

pf_stop() {
  mkdir -p "$STATE_DIR"
  local stopped=0
  for pidfile in "$STATE_DIR"/*.pid; do
    [[ -e "$pidfile" ]] || continue
    local pid; pid="$(cat "$pidfile")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "✓ 종료: $(basename "$pidfile" .pid) (pid ${pid})"
      stopped=1
    fi
    rm -f "$pidfile"
  done
  [[ "$stopped" == 0 ]] && echo "(종료할 터널 없음)"
}

# ──────────────────────────────────────────────────────────────────────────
main() {
  local cmd="${1:-}"
  case "$cmd" in
    pf) shift; cmd_pf "$@" ;;
    ssh) shift; cmd_ssh "$@" ;;
    ssh-key-register) shift; cmd_ssh_key_register "$@" ;;
    ""|-h|--help) usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
