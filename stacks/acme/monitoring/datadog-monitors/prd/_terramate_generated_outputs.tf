// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

output "pod_restart_monitor_id" {
  description = "Datadog monitor ID for pod restart alert"
  value       = datadog_monitor.pod_restart.id
}
output "pod_restart_monitor_url" {
  description = "Datadog monitor URL for pod restart alert"
  value       = "https://app.${var.datadog_site}/monitors/${datadog_monitor.pod_restart.id}"
}
output "slack_channel_name" {
  description = "Slack channel that Datadog monitor notifies"
  value       = var.slack_channel_name
}
