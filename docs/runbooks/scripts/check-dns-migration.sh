#!/bin/bash
# DNS 전환 상태 확인 스크립트
# v2 ALB로 전환된 도메인인지 확인 → HTML 리포트 생성 (브라우저 자동 새로고침)
#
# 사용법: ./check-dns-migration.sh        (1회 실행 후 브라우저 열기)
#         ./check-dns-migration.sh watch   (30초마다 자동 갱신)

V2_ALB="acme-main-v2-prd-traefik-000000001.ap-northeast-2.elb.amazonaws.com"
OUTPUT="/tmp/dns-migration-status.html"
INTERVAL=30

# 단계별 도메인 (stage:domain)
DOMAINS=(
  "0:argocd.acme.example"
  "0:grafana.acme.example"
  "0:traefik.acme.example"
  "0:kafka.acme.example"
  "1:company-supply.acme.example"
  "1:partner-admin.acme.example"
  "1:venue-admin.acme.example"
  "1:venue-partner.acme.example"
  "2:acme-corp.example"
  "2:beacon.acme.example"
  "2:member.acme.example"
  "2:play.acme.example"
  "2:recommendation-api.acme.example"
  "3:api.acme.example"
  "3:apiv3.acme.example"
  "3:api.acmemall.example"
  "3:api-v4.acme.example"
)

STAGE_NAMES=("1단계: 내부 인프라" "2단계: 어드민/B2B" "3단계: 사용자 프론트엔드" "4단계: Core API")

check_domain() {
  local domain=$1
  local cname resolved alb_ips domain_ips
  cname=$(dig +short CNAME "$domain" 2>/dev/null)
  resolved=$(dig +short "$domain" 2>/dev/null | tail -1)
  alb_ips=$(dig +short "$V2_ALB" 2>/dev/null | sort)
  domain_ips=$(dig +short "$domain" 2>/dev/null | sort)

  if [[ "$cname" == *"$V2_ALB"* ]]; then
    echo "v2|CNAME → v2 ALB"
  elif [[ -n "$alb_ips" ]] && [[ "$domain_ips" == "$alb_ips" ]]; then
    echo "v2|A record → v2 ALB"
  elif [[ -n "$resolved" ]]; then
    echo "v1|→ ${resolved}"
  else
    echo "none|레코드 없음"
  fi
}

generate_html() {
  local timestamp total_v2=0 total_v1=0 total_none=0 total=${#DOMAINS[@]}
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # 결과 수집 (배열 인덱스 기반)
  local statuses=() details=()
  for i in "${!DOMAINS[@]}"; do
    local domain="${DOMAINS[$i]#*:}"
    local result
    result=$(check_domain "$domain")
    statuses[$i]="${result%%|*}"
    details[$i]="${result#*|}"
    case "${statuses[$i]}" in
      v2) ((total_v2++)) ;;
      v1) ((total_v1++)) ;;
      none) ((total_none++)) ;;
    esac
  done

  local pct=$((total_v2 * 100 / total))
  local pct_v1=$((total_v1 * 100 / total))
  local pct_none=$((total_none * 100 / total))

  # HTML 생성
  cat > "$OUTPUT" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="30">
<title>DNS Migration Status</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0d1117;color:#c9d1d9;padding:24px}
.hdr{text-align:center;margin-bottom:32px}
.hdr h1{font-size:24px;color:#f0f6fc;margin-bottom:8px}
.hdr .meta{font-size:13px;color:#8b949e}
.hdr .tm{color:#58a6ff}
.pw{max-width:600px;margin:20px auto}
.pb{height:32px;background:#161b22;border-radius:16px;overflow:hidden;border:1px solid #30363d;display:flex}
.sg{display:flex;align-items:center;justify-content:center;font-weight:600;font-size:14px;min-width:30px}
.sg-v2{background:linear-gradient(90deg,#238636,#2ea043);color:#fff}
.sg-v1{background:#d29922;color:#000}
.sg-no{background:#484f58;color:#c9d1d9}
.st{display:flex;justify-content:center;gap:24px;margin-top:12px;font-size:14px}
.cv2{color:#3fb950}.cv1{color:#d29922}.cno{color:#8b949e}
.wrap{max-width:800px;margin:0 auto}
.card{background:#161b22;border:1px solid #30363d;border-radius:12px;margin-bottom:16px;overflow:hidden}
.ch{padding:12px 20px;border-bottom:1px solid #30363d;display:flex;justify-content:space-between;align-items:center}
.ch h2{font-size:16px;color:#f0f6fc}
.bg{font-size:12px;padding:2px 10px;border-radius:10px;font-weight:600}
.bg-ok{background:#238636;color:#fff}
.bg-pt{background:#d29922;color:#000}
.bg-no{background:#484f58;color:#c9d1d9}
.dl{padding:4px 0}
.d{display:flex;align-items:center;padding:10px 20px;border-bottom:1px solid #21262d}
.d:last-child{border-bottom:none}
.d .ic{width:28px;font-size:18px}
.d .nm{flex:1;font-family:'SF Mono',Monaco,monospace;font-size:14px}
.d .dt{font-size:12px;color:#8b949e}
.iv2{color:#3fb950}.iv1{color:#d29922}.ino{color:#484f58}
.ft{text-align:center;margin-top:24px;font-size:12px;color:#484f58}
</style>
</head>
<body>
HTMLHEAD

  cat >> "$OUTPUT" << HTMLPROG
<div class="hdr">
  <h1>DNS Migration Status — v1 → v2</h1>
  <div class="meta">v2 ALB: <code>${V2_ALB:0:50}...</code><br>마지막 확인: <span class="tm">${timestamp}</span></div>
</div>
<div class="pw"><div class="pb">
HTMLPROG

  [[ $pct -gt 0 ]] && echo "<div class=\"sg sg-v2\" style=\"width:${pct}%\">${total_v2}</div>" >> "$OUTPUT"
  [[ $pct_v1 -gt 0 ]] && echo "<div class=\"sg sg-v1\" style=\"width:${pct_v1}%\">${total_v1}</div>" >> "$OUTPUT"
  [[ $pct_none -gt 0 ]] && echo "<div class=\"sg sg-no\" style=\"width:${pct_none}%\">${total_none}</div>" >> "$OUTPUT"

  cat >> "$OUTPUT" << HTMLST
</div><div class="st">
  <span class="cv2">● v2 전환: ${total_v2}/${total} (${pct}%)</span>
  <span class="cv1">● v1 유지: ${total_v1}</span>
  <span class="cno">● 없음: ${total_none}</span>
</div></div>
<div class="wrap">
HTMLST

  # Stage 카드 생성
  for si in 0 1 2 3; do
    local s_v2=0 s_total=0
    for i in "${!DOMAINS[@]}"; do
      [[ "${DOMAINS[$i]%%:*}" == "$si" ]] && ((s_total++)) && [[ "${statuses[$i]}" == "v2" ]] && ((s_v2++))
    done

    local bc="bg-no" bt="대기"
    [[ $s_v2 -eq $s_total ]] && bc="bg-ok" && bt="완료"
    [[ $s_v2 -gt 0 ]] && [[ $s_v2 -lt $s_total ]] && bc="bg-pt" && bt="${s_v2}/${s_total}"

    echo "<div class=\"card\"><div class=\"ch\"><h2>${STAGE_NAMES[$si]}</h2><span class=\"bg ${bc}\">${bt}</span></div><div class=\"dl\">" >> "$OUTPUT"

    for i in "${!DOMAINS[@]}"; do
      [[ "${DOMAINS[$i]%%:*}" != "$si" ]] && continue
      local domain="${DOMAINS[$i]#*:}"
      local ic_cls="ino" ic="✗"
      case "${statuses[$i]}" in
        v2) ic_cls="iv2"; ic="✓" ;;
        v1) ic_cls="iv1"; ic="→" ;;
      esac
      echo "<div class=\"d\"><span class=\"ic ${ic_cls}\">${ic}</span><span class=\"nm\">${domain}</span><span class=\"dt\">${details[$i]}</span></div>" >> "$OUTPUT"
    done

    echo "</div></div>" >> "$OUTPUT"
  done

  echo '</div><div class="ft">30초마다 자동 새로고침</div></body></html>' >> "$OUTPUT"
  echo "[$(date '+%H:%M:%S')] 갱신 → ${OUTPUT}"
}

# 실행
generate_html

if [[ "$1" == "watch" ]]; then
  open "$OUTPUT" 2>/dev/null || xdg-open "$OUTPUT" 2>/dev/null
  echo "브라우저에서 열림. ${INTERVAL}초마다 자동 갱신. Ctrl+C로 종료."
  while true; do
    sleep "$INTERVAL"
    generate_html
  done
else
  open "$OUTPUT" 2>/dev/null || xdg-open "$OUTPUT" 2>/dev/null
  echo "실시간 갱신: ./check-dns-migration.sh watch"
fi
