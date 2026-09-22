// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "aws_secretsmanager_secret_version" "datadog" {
  secret_id = var.datadog_secret_name
}
provider "datadog" {
  api_key = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["DD_API_KEY"]
  api_url = "https://api.${var.datadog_site}/"
  app_key = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["DD_APP_KEY"]
}
import {
  id = "${var.slack_account_name}:${var.slack_channel_name}"
  to = datadog_integration_slack_channel.alert
}
resource "datadog_integration_slack_channel" "alert" {
  account_name = var.slack_account_name
  channel_name = var.slack_channel_name
  display {
    message  = true
    notified = false
    snapshot = false
    tags     = false
  }
}
resource "datadog_monitor" "pod_restart" {
  evaluation_delay         = 60
  include_tags             = false
  message                  = local.monitor_message
  name                     = local.monitor_name
  notification_preset_name = "hide_all"
  notify_audit             = false
  notify_no_data           = false
  priority                 = var.monitor_priority
  query                    = local.pod_restart_query
  renotify_interval        = 0
  require_full_window      = false
  tags                     = local.monitor_tags
  type                     = "metric alert"
  monitor_thresholds {
    critical = var.monitor_restart_threshold
  }
}
