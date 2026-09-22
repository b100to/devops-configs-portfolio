#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OIDC_SCRIPT="${SCRIPT_DIR}/aws-oidc.sh"

usage() {
  cat <<'EOF'
Usage:
  aws-url-handler.sh 'acme-aws://login?env=dev'

Supported URLs:
  acme-aws://login?env=dev
  acme-aws://login?env=prd
  acme-aws://setup-config
  acme-aws://whoami
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || die "This handler only supports macOS."
command -v osascript >/dev/null 2>&1 || die "osascript is required."
command -v python3 >/dev/null 2>&1 || die "python3 is required."
[[ -x "${OIDC_SCRIPT}" ]] || die "Cannot execute: ${OIDC_SCRIPT}"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage
  exit 0
fi

url="$1"

mapfile -t parsed < <(python3 - "${url}" <<'PYEOF'
import sys
from urllib.parse import parse_qs, urlparse

u = urlparse(sys.argv[1])
if u.scheme != "acme-aws":
    print("INVALID_SCHEME")
    sys.exit(10)

action = u.netloc or u.path.lstrip("/").split("/", 1)[0]
query = parse_qs(u.query)
env = (query.get("env") or [""])[0]
port = (query.get("port") or [""])[0]

print(action)
print(env)
print(port)
PYEOF
) || die "Invalid URL: ${url}"

action="${parsed[0]:-}"
env="${parsed[1]:-}"
port="${parsed[2]:-}"

cmd=("${OIDC_SCRIPT}")

case "${action}" in
  ""|login)
    [[ -n "${env}" ]] || env="dev"
    if [[ "${env}" != "dev" && "${env}" != "prd" ]]; then
      die "Unsupported env '${env}'. Use dev or prd."
    fi
    if [[ -n "${port}" ]]; then
      [[ "${port}" =~ ^[0-9]+$ ]] || die "Port must be numeric: ${port}"
      cmd+=(--port "${port}")
    fi
    cmd+=(login "${env}")
    ;;
  setup-config|setup_config)
    cmd+=(setup-config)
    ;;
  whoami)
    cmd+=(whoami)
    ;;
  *)
    die "Unsupported action '${action}'."
    ;;
esac

cmd_line="$(python3 - "${cmd[@]}" <<'PYEOF'
import shlex
import sys
print(shlex.join(sys.argv[1:]))
PYEOF
)"

# Escape for AppleScript string literal.
apple_cmd="${cmd_line//\\/\\\\}"
apple_cmd="${apple_cmd//\"/\\\"}"

osascript <<EOF
tell application "Terminal"
  activate
  do script "${apple_cmd}"
end tell
EOF
