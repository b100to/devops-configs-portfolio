environment = "prd"
account_id  = "222222222222"

cluster_name = "acme-main-v2-prd"

# external-secrets 가 사용 중인 시크릿 재사용 (DD_API_KEY, DD_APP_KEY 필드)
# APP key 는 monitors_write 스코프가 필요 — 운영 체크리스트 참조
datadog_secret_name = "eks/acme-main-v2-prd"
datadog_site        = "datadoghq.com"

# Datadog Slack workspace 이름 (대소문자 구분)
# Datadog UI → Integrations → Slack → Configure → Slack account name
# NOTE: 2026-04-23 Datadog Slack app 재설치로 monitor → Slack 경로 정상화.
# monitor 메시지 템플릿은 Terraform 소스(locals.tm.hcl) 가 정본이며 UI 수정분은 이 apply 로 원복됨.
slack_account_name = "Acme"
slack_channel_name = "#monitoring"

# 5분 윈도우 내 restart 카운터 증가 감지 (> 0 = 한 번이라도 restart)
monitor_evaluation_window_min = 5
monitor_restart_threshold     = 0
monitor_priority              = 3

notification_tags = [
  "team:devops",
  "service:kubernetes",
]
