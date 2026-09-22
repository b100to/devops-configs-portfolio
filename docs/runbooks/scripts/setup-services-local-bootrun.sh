#!/usr/bin/env bash
# AcmeCorp/services 로컬 bootRun 셋업 (1회 실행)
#
# 1. sudoers NOPASSWD for kubefwd
# 2. ~/Library/LaunchAgents/com.acme.kubefwd-dev.plist 생성/갱신
# 3. LaunchAgent reload
# 4. /etc/hosts 등록 확인
#
# 사용법:  bash setup-services-local-bootrun.sh
# (sudo 비밀번호 1회 입력)

set -euo pipefail

USER_HOME="$HOME"
PLIST_PATH="$USER_HOME/Library/LaunchAgents/com.acme.kubefwd-dev.plist"
KUBEFWD_BIN="/opt/homebrew/bin/kubefwd"
SUDOERS_PATH="/etc/sudoers.d/kubefwd"
KUBE_CONTEXT="acme-dev"

# ─────────────────────────────────────────────
# 사전 확인
# ─────────────────────────────────────────────
[[ ! -x "$KUBEFWD_BIN" ]] && { echo "❌ $KUBEFWD_BIN 없음. 'brew install txn2/tap/kubefwd' 먼저"; exit 1; }
kubectl config get-contexts -o name 2>/dev/null | grep -q "^${KUBE_CONTEXT}$" || \
  { echo "❌ kubectl context '${KUBE_CONTEXT}' 없음"; exit 1; }

echo "==> 1/4 sudoers NOPASSWD 셋업"
if [[ ! -f "$SUDOERS_PATH" ]]; then
  echo "$USER ALL=(ALL) NOPASSWD: $KUBEFWD_BIN" | sudo tee "$SUDOERS_PATH" >/dev/null
  sudo chmod 440 "$SUDOERS_PATH"
  echo "   ✓ $SUDOERS_PATH 생성"
else
  echo "   ✓ 이미 존재 — 스킵"
fi

echo "==> 2/4 기존 kubefwd 프로세스 정리"
sudo pkill -f "kubefwd svc" 2>/dev/null || true
sleep 2

echo "==> 3/4 LaunchAgent plist 생성"
mkdir -p "$(dirname "$PLIST_PATH")"
cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.acme.kubefwd-dev</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/sudo</string>
        <string>-n</string>
        <string>${KUBEFWD_BIN}</string>
        <string>svc</string>
        <string>-n</string>
        <string>default</string>
        <string>-n</string>
        <string>kafka</string>
        <string>--context=${KUBE_CONTEXT}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${USER_HOME}/.asdf/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin</string>
        <key>HOME</key>
        <string>${USER_HOME}</string>
        <key>KUBECONFIG</key>
        <string>${USER_HOME}/.kube/config</string>
    </dict>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key><false/>
        <key>Crashed</key><true/>
    </dict>
    <key>ThrottleInterval</key><integer>30</integer>
    <key>StandardOutPath</key><string>/tmp/kubefwd-dev.log</string>
    <key>StandardErrorPath</key><string>/tmp/kubefwd-dev.err</string>
</dict>
</plist>
PLIST
echo "   ✓ $PLIST_PATH"

echo "==> 4/4 LaunchAgent reload + 등록 확인 (25s)"
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load -w "$PLIST_PATH"
sleep 25

if pgrep -fl "kubefwd svc" >/dev/null; then
  echo "   ✓ kubefwd 떠있음"
else
  echo "   ❌ kubefwd 미기동. /tmp/kubefwd-dev.err 확인"; exit 1
fi

REGISTERED=$(grep -cE "venue-mysql|mall-mysql|kafka\." /etc/hosts || true)
[[ "$REGISTERED" -ge 3 ]] && echo "   ✓ /etc/hosts 등록 (line ${REGISTERED}건)" || { echo "   ❌ /etc/hosts 등록 부족"; exit 1; }

echo
echo "🎉 셋업 완료. 다음:"
echo "  1) aws-oidc login dev"
echo "  2) IntelliJ Run Config 의 환경변수 설정 (services-local-bootrun.md §4 참조)"
echo "  3) ▶ ServicesApplication"
