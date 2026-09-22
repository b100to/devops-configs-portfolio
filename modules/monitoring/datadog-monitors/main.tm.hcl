generate_hcl "_terramate_generated_main.tf" {
  content {
    # --- Datadog credentials from AWS Secrets Manager ---
    # external-secrets 에서 사용 중인 시크릿을 그대로 재사용 (eks/acme-main-v2-prd)
    data "aws_secretsmanager_secret_version" "datadog" {
      secret_id = var.datadog_secret_name
    }

    # --- Datadog provider ---
    # api_key/app_key 는 data source 로 주입. APP key 는 monitors_write 스코프 필요
    provider "datadog" {
      api_key = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["DD_API_KEY"]
      app_key = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["DD_APP_KEY"]
      api_url = "https://api.${var.datadog_site}/"
    }

    # --- Slack channel display options (import block 으로 기존 채널 흡수) ---
    # Workspace OAuth 연결 + 채널 등록은 Datadog UI 수동 작업. 이 리소스는 이미
    # 등록된 채널의 "Channels available for monitor alerts" display 옵션만 관리.
    # Terraform 1.5+ import block 으로 기존 등록을 state 에 편입 → create 시
    # "already configured" 에러 회피.
    import {
      to = datadog_integration_slack_channel.alert
      id = "${var.slack_account_name}:${var.slack_channel_name}"
    }

    resource "datadog_integration_slack_channel" "alert" {
      account_name = var.slack_account_name
      channel_name = var.slack_channel_name

      display {
        message  = true  # 본문 표시
        notified = false # "Notified: @slack-..." 섹션 제거 (중복)
        snapshot = false # 그래프 이미지 제거
        tags     = false # "Tags: kube_container_name:..." 섹션 제거 (본문에 동일 정보)
      }
    }

    # --- Pod restart monitor ---
    resource "datadog_monitor" "pod_restart" {
      name     = local.monitor_name
      type     = "metric alert"
      message  = local.monitor_message
      priority = var.monitor_priority
      tags     = local.monitor_tags

      query = local.pod_restart_query

      monitor_thresholds {
        critical = var.monitor_restart_threshold
      }

      # 배포/HPA rolling 중 발생하는 순간적 NO DATA 로 오탐 방지
      notify_no_data      = false
      require_full_window = false

      # 제목의 "on kube_container_name:..., kube_namespace:..., pod_name:..."
      # triggering tags 섹션 제거 (본문에 이미 동일 정보 표시)
      include_tags = false

      # 자동 첨부되는 쿼리 설명("The change in ...") + 본문의 `@slack-...`
      # 핸들을 숨겨서 알림 메시지 최소화
      notification_preset_name = "hide_all"

      # pod 이름/컨테이너는 재배포마다 바뀜 → 그룹별 renotify 무의미
      renotify_interval = 0

      # Datadog Agent 데이터 도착 지연 고려
      evaluation_delay = 60

      # Recovery 알림 최소화 (message template 에서 recovery 블록 제거)
      notify_audit = false
    }
  }
}
