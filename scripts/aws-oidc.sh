#!/usr/bin/env bash
set -euo pipefail

# Fix macOS python.org SSL cert issue (no CA certs by default)
if [[ -z "${SSL_CERT_FILE:-}" && -f /etc/ssl/cert.pem ]]; then
  export SSL_CERT_FILE=/etc/ssl/cert.pem
fi

# AWS CLI credential_process via authentik OIDC (Authorization Code + PKCE).
#
# Flow:
#   1) First run: opens browser for Google SSO -> authentik -> OIDC tokens
#   2) Tokens cached locally (id_token + refresh_token)
#   3) Subsequent runs: refresh_token auto-renews id_token (no browser)
#   4) credential_process returns JSON for AWS CLI
#
# Commands:
#   login <dev|prd>
#   credential-process <dev|prd>
#   config-snippet
#   whoami                           # decode cached id_token
#
# Requirements: python3, openssl (for PKCE), curl/wget

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# --- Config ---
OIDC_ISSUER="https://sso.acme.example/application/o/aws-cli/"
OIDC_CLIENT_ID="aws-cli"
# authentik shared endpoints (authorize, token, etc.) live under /application/o/
OIDC_BASE_URL="${OIDC_ISSUER%/${OIDC_CLIENT_ID}/}"
OIDC_SCOPES="openid email profile groups offline_access"
CALLBACK_PORT="${AWS_OIDC_CALLBACK_PORT:-18400}"
CACHE_DIR="${AWS_OIDC_CACHE_DIR:-$HOME/.cache/aws-oidc}"
REGION="${AWS_DEFAULT_REGION:-ap-northeast-2}"

# Role ARNs per environment
DEV_ACCOUNT="111111111111"
PRD_ACCOUNT="222222222222"

usage() {
  cat <<'EOF'
Usage:
  aws-oidc.sh [options] <command> [args...]

Commands:
  login <dev|prd>                    Browser login, cache tokens
  credential-process <dev|prd>       Output JSON for AWS credential_process
  setup-config                       Patch ~/.aws/config + kubeconfig 전체 설정
  config-snippet                     Print AWS config snippet
  whoami                             Decode cached id_token

Options:
  --region <region>           AWS region (default: ap-northeast-2)
  --port <port>               Localhost callback port (default: 18400)
  -h, --help                  Show this help

Examples:
  aws-oidc.sh login dev
  aws-oidc.sh credential-process prd
  aws-oidc.sh config-snippet >> ~/.aws/config
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

# --- Argument parsing ---
role_override=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --role) role_override="${2:-}"; shift 2 ;;
    --region) REGION="${2:-}"; shift 2 ;;
    --port) CALLBACK_PORT="${2:-}"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

cmd="${1:-}"
shift || true

# --- Helpers ---
ensure_cache() {
  mkdir -p "${CACHE_DIR}" 2>/dev/null || true
  chmod 700 "${CACHE_DIR}" 2>/dev/null || true
}

base64url_encode() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

generate_pkce() {
  local verifier
  verifier="$(openssl rand 32 | base64url_encode)"
  local challenge
  challenge="$(printf '%s' "${verifier}" | openssl dgst -sha256 -binary | base64url_encode)"
  echo "${verifier}" "${challenge}"
}

generate_state() {
  openssl rand 16 | base64url_encode
}

# Decode JWT payload (no verification - just parse claims)
decode_jwt_payload() {
  local token="$1"
  local payload
  payload="$(echo "${token}" | cut -d. -f2)"
  # Add padding
  local pad=$(( 4 - ${#payload} % 4 ))
  if [[ ${pad} -lt 4 ]]; then
    payload="${payload}$(printf '%0.s=' $(seq 1 ${pad}))"
  fi
  echo "${payload}" | base64 -d 2>/dev/null || echo "${payload}" | openssl base64 -d -A 2>/dev/null
}

get_role_arn() {
  local env="$1"
  local role="$2"
  local account
  case "${env}" in
    dev) account="${DEV_ACCOUNT}" ;;
    prd) account="${PRD_ACCOUNT}" ;;
    *) die "unknown env: ${env}" ;;
  esac
  echo "arn:aws:iam::${account}:role/authentik-oidc-${role}"
}

# Role is always admin (single-role model; group management is via authentik devops-admin group)
detect_role() {
  echo "admin"
}

# --- OIDC Token Flow ---
# Single Python process: PKCE + callback server + token exchange (avoids cross-process issues)
oidc_authorize() {
  local env="$1"
  ensure_cache

  echo "Opening browser for authentication..." >&2

  local oidc_script
  oidc_script="$(mktemp)"
  cat > "${oidc_script}" <<'PYEOF'
import http.server, urllib.parse, urllib.request, hashlib, base64
import os, json, sys, threading, subprocess, secrets, signal, time

base_url, client_id, port_str, scopes, cache_dir = sys.argv[1:6]
port = int(port_str)

# Kill any stale process still holding the callback port (e.g. from a previous aborted login).
# This prevents "Address already in use" when the user re-runs the command before the old
# Python process times out (60 s window).
try:
    lsof = subprocess.run(
        ['lsof', '-ti', 'TCP:' + str(port), '-sTCP:LISTEN'],
        capture_output=True, text=True, timeout=3
    )
    stale_pids = [p.strip() for p in lsof.stdout.strip().splitlines() if p.strip()]
    for pid_str in stale_pids:
        try:
            os.kill(int(pid_str), signal.SIGTERM)
            print(f"Killed stale login process (pid {pid_str}) on port {port}", file=sys.stderr)
        except (ProcessLookupError, ValueError):
            pass
    if stale_pids:
        time.sleep(0.5)  # allow OS to release socket before we bind
except Exception:
    pass

# PKCE
verifier = base64.urlsafe_b64encode(secrets.token_bytes(32)).rstrip(b"=").decode()
challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
state = base64.urlsafe_b64encode(secrets.token_bytes(16)).rstrip(b"=").decode()

# Authorize URL
params = {
    "response_type": "code",
    "client_id": client_id,
    "redirect_uri": f"http://localhost:{port}/callback",
    "scope": scopes,
    "state": state,
    "code_challenge": challenge,
    "code_challenge_method": "S256",
}
auth_url = f"{base_url}/authorize/?{urllib.parse.urlencode(params)}"

# Callback server
result = {}

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        qs = urllib.parse.parse_qs(parsed.query)
        if parsed.path == "/callback":
            code = qs.get("code", [None])[0]
            cb_state = qs.get("state", [None])[0]
            error = qs.get("error", [None])[0]
            if error:
                result["error"] = error
                self.send_response(400)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(f"<h2>Error: {error}</h2>".encode())
            elif cb_state != state:
                result["error"] = "state_mismatch"
                self.send_response(400)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(b"<h2>State mismatch</h2>")
            else:
                result["code"] = code
                self.send_response(200)
                self.send_header("Content-Type", "text/html")
                self.end_headers()
                self.wfile.write(b"<h2>Authentication successful!</h2><p>This tab will close in 3 seconds.</p><script>setTimeout(function(){window.close()},3000)</script>")
        else:
            self.send_response(404)
            self.end_headers()
        # daemon=True: won't block process exit if main thread already exiting
        threading.Thread(target=self.server.shutdown, daemon=True).start()

    def log_message(self, *a):
        pass

# allow_reuse_address lets the next run reclaim the port immediately after SIGTERM above
class ReusableHTTPServer(http.server.HTTPServer):
    allow_reuse_address = True

server = ReusableHTTPServer(("127.0.0.1", port), Handler)
# daemon=True: Ctrl+C on the parent shell kills this thread immediately
srv_thread = threading.Thread(target=server.serve_forever, daemon=True)
srv_thread.start()

# Remember current foreground app (macOS) to restore focus after callback
prev_app = None
if sys.platform == "darwin":
    try:
        prev_app = subprocess.check_output(["osascript", "-e",
            'tell application "System Events" to get name of first application process whose frontmost is true'],
            stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        pass

# Open browser
for cmd in ["xdg-open", "open", "wslview"]:
    import shutil
    if shutil.which(cmd):
        subprocess.Popen([cmd, auth_url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        break
else:
    print(f"Open: {auth_url}", file=sys.stderr)

TIMEOUT = 120
print(f"Waiting for authentication callback on localhost:{port} (timeout: {TIMEOUT}s)...", file=sys.stderr)
srv_thread.join(timeout=TIMEOUT)

# Proper cleanup: stop serve_forever() before closing the socket
if srv_thread.is_alive():
    server.shutdown()
server.server_close()

if "error" in result:
    print(json.dumps({"error": result["error"]}))
    sys.exit(1)

code = result.get("code")
if not code:
    print(json.dumps({"error": "login_timeout"}))
    print(f"Login timed out after {TIMEOUT}s — run the command again to retry.", file=sys.stderr)
    sys.exit(1)

# Token exchange (same process, no delay)
token_data = urllib.parse.urlencode({
    "grant_type": "authorization_code",
    "client_id": client_id,
    "code": code,
    "redirect_uri": f"http://localhost:{port}/callback",
    "code_verifier": verifier,
}).encode()

req = urllib.request.Request(
    f"{base_url}/token/", data=token_data, method="POST",
    headers={"Content-Type": "application/x-www-form-urlencoded"},
)

try:
    resp = urllib.request.urlopen(req, timeout=30)
    data = json.loads(resp.read().decode())
except urllib.error.HTTPError as e:
    data = json.loads(e.read().decode())

# Cache tokens
if "id_token" in data:
    os.makedirs(cache_dir, mode=0o700, exist_ok=True)
    for name in ["id_token", "refresh_token"]:
        if data.get(name):
            path = os.path.join(cache_dir, name)
            with open(path, "w") as f:
                f.write(data[name])
            os.chmod(path, 0o600)
    print("Login successful!", file=sys.stderr)
    # Bring terminal back to foreground (macOS)
    if sys.platform == "darwin" and prev_app:
        try:
            subprocess.Popen(["osascript", "-e",
                f'tell application "{prev_app}" to activate'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

# Output the full token response as JSON (shell will parse)
print(json.dumps(data))
PYEOF

  local token_response
  token_response="$(python3 "${oidc_script}" \
    "${OIDC_BASE_URL}" "${OIDC_CLIENT_ID}" "${CALLBACK_PORT}" \
    "${OIDC_SCOPES}" "${CACHE_DIR}")" || true
  rm -f "${oidc_script}"

  local id_token refresh_token
  id_token="$(echo "${token_response}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id_token',''))" 2>/dev/null || echo "")"
  refresh_token="$(echo "${token_response}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null || echo "")"

  if [[ -z "${id_token}" ]]; then
    die "Token exchange failed. Response: ${token_response}"
  fi

  echo "${id_token}"
}

# Refresh id_token using refresh_token
oidc_refresh() {
  ensure_cache
  local refresh_token
  [[ -f "${CACHE_DIR}/refresh_token" ]] || return 1
  refresh_token="$(cat "${CACHE_DIR}/refresh_token")"
  [[ -n "${refresh_token}" ]] || return 1

  local token_url="${OIDC_BASE_URL}/token/"
  local token_response
  token_response="$(python3 -c "
import urllib.request, urllib.parse, sys
data = urllib.parse.urlencode({
    'grant_type': 'refresh_token',
    'client_id': sys.argv[1],
    'refresh_token': sys.argv[2],
}).encode()
req = urllib.request.Request(sys.argv[3], data=data, method='POST')
req.add_header('Content-Type', 'application/x-www-form-urlencoded')
try:
    resp = urllib.request.urlopen(req)
    print(resp.read().decode())
except urllib.error.HTTPError as e:
    print(e.read().decode())
" "${OIDC_CLIENT_ID}" "${refresh_token}" "${token_url}" 2>/dev/null)" || return 1

  local id_token new_refresh_token
  id_token="$(echo "${token_response}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id_token',''))" 2>/dev/null || echo "")"
  new_refresh_token="$(echo "${token_response}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null || echo "")"

  if [[ -z "${id_token}" ]]; then
    return 1
  fi

  echo "${id_token}" > "${CACHE_DIR}/id_token"
  if [[ -n "${new_refresh_token}" ]]; then
    echo "${new_refresh_token}" > "${CACHE_DIR}/refresh_token"
  fi
  chmod 600 "${CACHE_DIR}/id_token" "${CACHE_DIR}/refresh_token" 2>/dev/null || true

  echo "${id_token}"
}

# Get valid id_token (from cache, refresh, or new login)
get_id_token() {
  local env="$1"

  # Try cached token
  if [[ -f "${CACHE_DIR}/id_token" ]]; then
    local cached
    cached="$(cat "${CACHE_DIR}/id_token")"
    if [[ -n "${cached}" ]]; then
      local claims
      claims="$(decode_jwt_payload "${cached}")"
      local exp now
      exp="$(echo "${claims}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exp',0))" 2>/dev/null || echo 0)"
      now="$(date +%s)"
      if [[ $((exp - now)) -gt 60 ]]; then
        echo "${cached}"
        return 0
      fi
    fi
  fi

  # Try refresh
  local refreshed
  refreshed="$(oidc_refresh 2>/dev/null || echo "")"
  if [[ -n "${refreshed}" ]]; then
    echo "${refreshed}"
    return 0
  fi

  # Do NOT auto-open a browser here: credential-process is invoked silently by
  # background pollers (kubectl watch, k9s, IDE extensions, ...). If refresh keeps
  # failing and nobody completes the login, each poll would pop a new browser tab
  # forever, stacking up hundreds of windows overnight. Require an explicit login.
  die "AWS session expired for '${env}' and refresh failed. Run: aws-oidc login ${env}"
}

# Assume AWS role with OIDC token
assume_role_with_oidc() {
  local env="$1"
  local id_token="$2"
  local role="${3:-}"

  # Auto-detect role if not specified
  if [[ -z "${role}" ]]; then
    role="$(detect_role "${id_token}")"
  fi

  local role_arn
  role_arn="$(get_role_arn "${env}" "${role}")"

  local session_name
  session_name="$(decode_jwt_payload "${id_token}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('email','oidc-user').split('@')[0])" 2>/dev/null || echo "oidc-session")"

  # Use AWS CLI to assume role.
  # --no-sign-request: AssumeRoleWithWebIdentity is an anonymous STS API — no AWS credentials
  # needed. Without this flag, aws CLI tries to resolve credentials via credential_process,
  # which re-invokes this very script and creates an infinite recursion when AWS_PROFILE is set.
  local sts_response
  sts_response="$(aws sts assume-role-with-web-identity \
    --no-sign-request \
    --region "${REGION}" \
    --role-arn "${role_arn}" \
    --role-session-name "${session_name}" \
    --web-identity-token "${id_token}" \
    --duration-seconds 43200 \
    --output json 2>&1)" || die "AssumeRoleWithWebIdentity failed: ${sts_response}"

  echo "${sts_response}"
}

# --- Credential cache helpers ---

# Atomic mkdir-based lock (no flock dependency; works on macOS + Linux).
# Sets global _aws_oidc_lock_dir on success. Call _release_lock to clean up.
_lock_dir=""
_acquire_lock() {
  local name="$1"
  local lock_path="${CACHE_DIR}/.lock_${name}"
  local deadline=$(( $(date +%s) + 30 ))
  while ! mkdir "${lock_path}" 2>/dev/null; do
    # Stale lock detection: if the owning PID is gone, forcibly remove it.
    local pid
    pid="$(cat "${lock_path}/pid" 2>/dev/null || true)"
    if [[ -n "${pid}" ]] && ! kill -0 "${pid}" 2>/dev/null; then
      rm -rf "${lock_path}"
      continue
    fi
    if (( $(date +%s) >= deadline )); then
      return 1
    fi
    sleep 0.3
  done
  echo $$ > "${lock_path}/pid"
  _lock_dir="${lock_path}"
}

_release_lock() {
  if [[ -n "${_lock_dir}" ]]; then
    rm -rf "${_lock_dir}"
    _lock_dir=""
  fi
}

# Print cached STS JSON if still valid (>60 s remaining). Returns 1 if expired/absent.
_try_sts_cache() {
  local env="$1"
  [[ -f "${CACHE_DIR}/sts_${env}.json" ]] || return 1
  local cached expiration exp_epoch
  cached="$(cat "${CACHE_DIR}/sts_${env}.json")"
  expiration="$(echo "${cached}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('Expiration',''))" 2>/dev/null || echo "")"
  [[ -n "${expiration}" ]] || return 1
  exp_epoch="$(python3 -c "
from datetime import datetime, timezone
s='${expiration}'
try:
    dt = datetime.fromisoformat(s.replace('Z','+00:00'))
except Exception:
    dt = datetime.strptime(s, '%Y-%m-%dT%H:%M:%S+00:00').replace(tzinfo=timezone.utc)
print(int(dt.timestamp()))
" 2>/dev/null || echo 0)"
  (( $(date +%s) < exp_epoch - 60 )) || return 1
  echo "${cached}"
}

# --- Commands ---
do_login() {
  local env="${1:-}"
  [[ -n "${env}" ]] || die "usage: aws-oidc.sh login <dev|prd>"

  local id_token
  id_token="$(oidc_authorize "${env}")"

  local role="${role_override}"
  if [[ -z "${role}" ]]; then
    role="$(detect_role "${id_token}")"
  fi

  echo "Authenticated as role: ${role}" >&2

  local sts
  sts="$(assume_role_with_oidc "${env}" "${id_token}" "${role}")"

  # Cache STS credentials for credential-process
  local expiration
  expiration="$(echo "${sts}" | python3 -c "
import sys, json
c = json.load(sys.stdin)['Credentials']
out = {'Version':1,'AccessKeyId':c['AccessKeyId'],'SecretAccessKey':c['SecretAccessKey'],'SessionToken':c['SessionToken'],'Expiration':c['Expiration']}
json.dump(out, open(sys.argv[1],'w'))
print(c['Expiration'])
" "${CACHE_DIR}/sts_${env}.json")"
  chmod 600 "${CACHE_DIR}/sts_${env}.json"

  echo "AWS credentials cached for ${env} (expires: ${expiration})" >&2
}

do_credential_process() {
  local env="${1:-}"
  [[ -n "${env}" ]] || die "usage: aws-oidc.sh credential-process <dev|prd>"

  # Fast path: valid cache — no lock needed for a read.
  if _try_sts_cache "${env}"; then return 0; fi

  # Acquire an exclusive lock to prevent concurrent refresh stampede.
  # Without this, N simultaneous kubectl/terraform calls each spawn their own
  # refresh chain (N × aws sts calls) the moment credentials expire.
  ensure_cache
  _acquire_lock "${env}" || die "Timed out waiting for credential refresh lock for ${env}"
  trap '_release_lock' RETURN

  # Double-check: another process may have refreshed while we were waiting for the lock.
  if _try_sts_cache "${env}"; then return 0; fi

  # Get fresh id_token (refresh or interactive)
  local id_token
  id_token="$(get_id_token "${env}")"

  local role="${role_override}"
  if [[ -z "${role}" ]]; then
    role="$(detect_role "${id_token}")"
  fi

  local sts
  sts="$(assume_role_with_oidc "${env}" "${id_token}" "${role}")"

  # Build credential-process JSON, cache, and output
  echo "${sts}" | python3 -c "
import sys, json
c = json.load(sys.stdin)['Credentials']
out = {'Version':1,'AccessKeyId':c['AccessKeyId'],'SecretAccessKey':c['SecretAccessKey'],'SessionToken':c['SessionToken'],'Expiration':c['Expiration']}
json.dump(out, open(sys.argv[1],'w'))
print(json.dumps(out))
" "${CACHE_DIR}/sts_${env}.json"
  chmod 600 "${CACHE_DIR}/sts_${env}.json"
}

do_config_snippet() {
  local self="${SCRIPT_DIR}/aws-oidc.sh"
  local role_flag=""
  if [[ -n "${role_override}" ]]; then
    role_flag=" --role ${role_override}"
  fi
  cat <<EOF
# AWS CLI OIDC credential_process (authentik)
# First run: opens browser. After that: auto-refresh for 12h.
[profile dev]
region = ${REGION}
credential_process = ${self}${role_flag} credential-process dev

[profile prd]
region = ${REGION}
credential_process = ${self}${role_flag} credential-process prd
EOF
}

do_setup_config() {
  local self="${SCRIPT_DIR}/aws-oidc.sh"
  local role_flag=""
  if [[ -n "${role_override}" ]]; then
    role_flag=" --role ${role_override}"
  fi

  python3 - "${self}${role_flag}" <<'PYEOF'
import sys, os, re

script_path = sys.argv[1]
config_path = os.path.expanduser('~/.aws/config')

targets = {
    'dev': f'{script_path} credential-process dev',
    'prd': f'{script_path} credential-process prd',
}

lines = []
if os.path.exists(config_path):
    with open(config_path) as f:
        lines = f.readlines()

result = []
patched = set()
i = 0

while i < len(lines):
    line = lines[i]
    m = re.match(r'^\[profile\s+([\w-]+)\]', line.strip())
    if m:
        profile = m.group(1)
        result.append(line)
        i += 1
        section_lines = []
        while i < len(lines) and not lines[i].strip().startswith('['):
            section_lines.append(lines[i])
            i += 1
        if profile in targets:
            filtered = [l for l in section_lines if not re.match(r'^\s*credential_process\s*=', l)]
            trailing = []
            while filtered and not filtered[-1].strip():
                trailing.insert(0, filtered.pop())
            filtered.append(f'credential_process = {targets[profile]}\n')
            filtered.extend(trailing)
            result.extend(filtered)
            patched.add(profile)
            print(f'  Updated [profile {profile}]')
        else:
            result.extend(section_lines)
    else:
        result.append(line)
        i += 1

for profile, cred_process in targets.items():
    if profile not in patched:
        result.append(f'\n[profile {profile}]\n')
        result.append(f'region = ap-northeast-2\n')
        result.append(f'output = json\n')
        result.append(f'credential_process = {cred_process}\n')
        print(f'  Created [profile {profile}]')

os.makedirs(os.path.dirname(config_path), exist_ok=True)
with open(config_path, 'w') as f:
    f.writelines(result)
PYEOF

  # --- aws-eks-token 심링크 설정 ---
  local wrapper="${SCRIPT_DIR}/aws-eks-token.sh"
  local link_dir="$HOME/.local/bin"
  local link_path="${link_dir}/aws-eks-token"
  mkdir -p "${link_dir}"
  ln -sf "${wrapper}" "${link_path}"
  echo "  Symlinked aws-eks-token -> ${wrapper}"

  # --- kubeconfig 설정 (EKS 컨텍스트) ---
  local clusters=(
    "dev:${DEV_ACCOUNT}:acme-main-v2-dev:acme-dev"
    "prd:${PRD_ACCOUNT}:acme-main-v2-prd:acme-prd"
  )
  for entry in "${clusters[@]}"; do
    IFS=: read -r profile account cluster alias <<< "${entry}"
    local arn="arn:aws:eks:${REGION}:${account}:cluster/${cluster}"

    # 기존 ARN 기반 중복 컨텍스트 제거
    kubectl config delete-context "${arn}" 2>/dev/null || true

    echo "  Setting up kubeconfig: ${alias} (${cluster})"
    if ! aws eks update-kubeconfig \
      --region "${REGION}" \
      --name "${cluster}" \
      --profile "${profile}" \
      --alias "${alias}" 2>/dev/null; then
      echo "    → ${profile} login required, logging in..."
      do_login "${profile}"
      if ! aws eks update-kubeconfig \
        --region "${REGION}" \
        --name "${cluster}" \
        --profile "${profile}" \
        --alias "${alias}" 2>/dev/null; then
        echo "    ⚠ Skipped (login failed for ${profile})"
        continue
      fi
    fi

    # command를 aws-eks-token으로 교체 (stale 환경 변수 방지)
    kubectl config set "users.${arn}.exec.command" aws-eks-token 2>/dev/null || true
  done

  echo ""
  echo "Done. Next steps:"
  echo "  make aws-login-dev   # dev 로그인"
  echo "  make aws-login-prd   # prd 로그인"
  echo "  kubectl --context acme-dev get nodes"
}

do_whoami() {
  if [[ ! -f "${CACHE_DIR}/id_token" ]]; then
    die "No cached id_token. Run 'aws-oidc.sh login <env>' first."
  fi
  local token
  token="$(cat "${CACHE_DIR}/id_token")"
  decode_jwt_payload "${token}" | python3 -m json.tool
}

# --- Main ---
case "${cmd}" in
  login)
    do_login "$@"
    ;;
  credential-process|credential_process)
    do_credential_process "$@"
    ;;
  config-snippet|config_snippet)
    do_config_snippet
    ;;
  setup-config|setup_config)
    do_setup_config
    ;;
  whoami)
    do_whoami
    ;;
  ""|help|-h|--help)
    usage
    ;;
  *)
    die "unknown command: ${cmd}"
    ;;
esac
