#!/bin/bash
# =============================================================================
# DNS Weighted Migration Script
# v1 → v2 가중치 기반 점진적 전환
# =============================================================================

set -euo pipefail

export AWS_PROFILE=prd

# ALB 설정
V1_ALB="dualstack.acme-main-prd-istio-ingress-000000002.ap-northeast-2.elb.amazonaws.com."
V2_ALB="acme-main-v2-prd-traefik-000000001.ap-northeast-2.elb.amazonaws.com."
ALB_HOSTED_ZONE="Z0EXAMPLE0006"

# 도메인 → Hosted Zone 매핑
declare -A DOMAIN_ZONES=(
  ["api-v4.acme.example"]="Z0EXAMPLE0005"
  ["apiv3.acme.example"]="Z0EXAMPLE0005"
  ["api.acmemall.example"]="Z0EXAMPLE0003"
)

# 전환 단계: v1_weight v2_weight
STEPS=(
  "90 10"
  "50 50"
  "0 100"
)

WAIT_SECONDS=600  # 단계 간 대기 (10분)

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

update_weight() {
  local domain=$1
  local v1_weight=$2
  local v2_weight=$3
  local zone_id=${DOMAIN_ZONES[$domain]}

  echo "  [$domain] v1=${v1_weight}% v2=${v2_weight}%"

  aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" --change-batch "{
    \"Changes\": [
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"${domain}\",
          \"Type\": \"A\",
          \"SetIdentifier\": \"v1\",
          \"Weight\": ${v1_weight},
          \"AliasTarget\": {
            \"HostedZoneId\": \"${ALB_HOSTED_ZONE}\",
            \"DNSName\": \"${V1_ALB}\",
            \"EvaluateTargetHealth\": true
          }
        }
      },
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"${domain}\",
          \"Type\": \"A\",
          \"SetIdentifier\": \"v2\",
          \"Weight\": ${v2_weight},
          \"AliasTarget\": {
            \"HostedZoneId\": \"${ALB_HOSTED_ZONE}\",
            \"DNSName\": \"${V2_ALB}\",
            \"EvaluateTargetHealth\": true
          }
        }
      }
    ]
  }" > /dev/null
}

check_dns() {
  local domain=$1
  local ips
  ips=$(dig +short "$domain" A | sort | tr '\n' ' ')
  echo "  [$domain] → $ips"
}

show_status() {
  echo ""
  echo "--- DNS 확인 ---"
  for domain in "${!DOMAIN_ZONES[@]}"; do
    check_dns "$domain"
  done
  echo ""
}

rollback() {
  echo ""
  echo "🔙 롤백: 모든 도메인을 v1 100%로 복구합니다..."
  for domain in "${!DOMAIN_ZONES[@]}"; do
    update_weight "$domain" 100 0
  done
  echo "✅ 롤백 완료"
  show_status
  exit 0
}

finalize_domain() {
  local domain=$1
  local zone_id=${DOMAIN_ZONES[$domain]}

  echo "  [$domain] weighted → simple (v2 only)"

  aws route53 change-resource-record-sets --hosted-zone-id "$zone_id" --change-batch "{
    \"Changes\": [
      {
        \"Action\": \"DELETE\",
        \"ResourceRecordSet\": {
          \"Name\": \"${domain}\",
          \"Type\": \"A\",
          \"SetIdentifier\": \"v1\",
          \"Weight\": 0,
          \"AliasTarget\": {
            \"HostedZoneId\": \"${ALB_HOSTED_ZONE}\",
            \"DNSName\": \"${V1_ALB}\",
            \"EvaluateTargetHealth\": true
          }
        }
      },
      {
        \"Action\": \"DELETE\",
        \"ResourceRecordSet\": {
          \"Name\": \"${domain}\",
          \"Type\": \"A\",
          \"SetIdentifier\": \"v2\",
          \"Weight\": 100,
          \"AliasTarget\": {
            \"HostedZoneId\": \"${ALB_HOSTED_ZONE}\",
            \"DNSName\": \"${V2_ALB}\",
            \"EvaluateTargetHealth\": true
          }
        }
      },
      {
        \"Action\": \"CREATE\",
        \"ResourceRecordSet\": {
          \"Name\": \"${domain}\",
          \"Type\": \"A\",
          \"AliasTarget\": {
            \"HostedZoneId\": \"${ALB_HOSTED_ZONE}\",
            \"DNSName\": \"${V2_ALB}\",
            \"EvaluateTargetHealth\": true
          }
        }
      }
    ]
  }" > /dev/null
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

echo "============================================="
echo " DNS Weighted Migration: v1 → v2"
echo "============================================="
echo ""
echo "대상 도메인:"
for domain in "${!DOMAIN_ZONES[@]}"; do
  echo "  - $domain"
done
echo ""
echo "전환 단계: 10% → 50% → 100% (간격: $((WAIT_SECONDS/60))분)"
echo ""

# 현재 상태
echo "--- 현재 DNS ---"
for domain in "${!DOMAIN_ZONES[@]}"; do
  check_dns "$domain"
done
echo ""

case "${1:-}" in
  step)
    # 특정 단계만 실행: ./script.sh step <v1_weight> <v2_weight>
    v1_w=${2:?Usage: $0 step <v1_weight> <v2_weight>}
    v2_w=${3:?Usage: $0 step <v1_weight> <v2_weight>}
    echo "=== 수동 단계: v1=${v1_w}% v2=${v2_w}% ==="
    for domain in "${!DOMAIN_ZONES[@]}"; do
      update_weight "$domain" "$v1_w" "$v2_w"
    done
    sleep 5
    show_status
    ;;

  rollback)
    rollback
    ;;

  finalize)
    # 수동 finalize: weighted → simple (v2 only)
    echo "=== Finalize: weighted → simple (v2 only) ==="
    echo "⚠️  현재 v1=0, v2=100 상태에서만 실행하세요!"
    echo ""
    for domain in "${!DOMAIN_ZONES[@]}"; do
      finalize_domain "$domain"
    done
    sleep 5
    show_status
    echo "✅ 가중치 레코드 정리 완료. v2 단일 A 레코드로 전환되었습니다."
    ;;

  auto)
    # 자동 전환: 모든 단계를 순차 실행
    trap rollback SIGINT  # Ctrl+C로 롤백

    for i in "${!STEPS[@]}"; do
      read -r v1_w v2_w <<< "${STEPS[$i]}"
      step_num=$((i + 1))
      echo "=== Step ${step_num}/${#STEPS[@]}: v1=${v1_w}% v2=${v2_w}% ==="

      for domain in "${!DOMAIN_ZONES[@]}"; do
        update_weight "$domain" "$v1_w" "$v2_w"
      done

      sleep 5
      show_status

      if [ "$v2_w" -eq 100 ]; then
        echo "✅ 전환 완료! 모든 트래픽이 v2로 이동했습니다."
        echo "💡 정리하려면: $0 finalize"
        break
      fi

      echo "⏳ ${WAIT_SECONDS}초 대기... (Ctrl+C로 롤백)"
      echo ""
      sleep "$WAIT_SECONDS"
    done
    ;;

  *)
    echo "Usage:"
    echo "  $0 auto                    # 자동 전환 (10% → 50% → 100% → finalize, 10분 간격)"
    echo "  $0 step <v1_w> <v2_w>      # 수동 가중치 설정"
    echo "  $0 finalize                # weighted 제거 → v2 단일 A 레코드로 전환"
    echo "  $0 rollback                # v1 100%로 롤백"
    echo ""
    echo "Examples:"
    echo "  $0 step 90 10              # v2에 10% 트래픽"
    echo "  $0 step 50 50              # 50/50 분배"
    echo "  $0 step 0 100              # v2 100%"
    echo "  $0 finalize                # 전환 완료 후 정리"
    ;;
esac
