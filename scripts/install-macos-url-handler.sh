#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HANDLER_SCRIPT="${SCRIPT_DIR}/aws-url-handler.sh"
APP_NAME="Acme AWS Handler"
APP_DIR="${HOME}/Applications/${APP_NAME}.app"
PLIST_BUDDY="/usr/libexec/PlistBuddy"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

usage() {
  cat <<EOF
Usage:
  install-macos-url-handler.sh

Installs macOS URL handler app:
  ${APP_DIR}

Registered URL scheme:
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

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

[[ "$(uname -s)" == "Darwin" ]] || die "This installer only supports macOS."
command -v osacompile >/dev/null 2>&1 || die "osacompile is required."
[[ -x "${PLIST_BUDDY}" ]] || die "Missing ${PLIST_BUDDY}"
[[ -f "${HANDLER_SCRIPT}" ]] || die "Missing ${HANDLER_SCRIPT}"

chmod +x "${HANDLER_SCRIPT}"
mkdir -p "${HOME}/Applications"

osascript_src="$(mktemp)"
trap 'rm -f "${osascript_src}"' EXIT

cat > "${osascript_src}" <<EOF
on open location this_URL
  do shell script quoted form of "${HANDLER_SCRIPT}" & space & quoted form of this_URL
end open location

on run argv
  if (count of argv) > 0 then
    set this_URL to item 1 of argv
    do shell script quoted form of "${HANDLER_SCRIPT}" & space & quoted form of this_URL
  else
    display dialog "Use URL: acme-aws://login?env=dev" buttons {"OK"} default button "OK"
  end if
end run
EOF

rm -rf "${APP_DIR}"
osacompile -o "${APP_DIR}" "${osascript_src}"

plist="${APP_DIR}/Contents/Info.plist"

"${PLIST_BUDDY}" -c "Delete :CFBundleURLTypes" "${plist}" >/dev/null 2>&1 || true
"${PLIST_BUDDY}" -c "Add :CFBundleURLTypes array" "${plist}"
"${PLIST_BUDDY}" -c "Add :CFBundleURLTypes:0 dict" "${plist}"
"${PLIST_BUDDY}" -c "Add :CFBundleURLTypes:0:CFBundleURLName string acme.aws.handler" "${plist}"
"${PLIST_BUDDY}" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "${plist}"
"${PLIST_BUDDY}" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string acme-aws" "${plist}"

if [[ -x "${LSREGISTER}" ]]; then
  "${LSREGISTER}" -f "${APP_DIR}" >/dev/null 2>&1 || true
fi

echo "Installed: ${APP_DIR}"
echo "Registered scheme: acme-aws"
echo ""
echo "Quick test:"
echo "  open 'acme-aws://login?env=dev'"
