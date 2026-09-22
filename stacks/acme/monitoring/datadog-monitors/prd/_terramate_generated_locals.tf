// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  monitor_message = <<-EOT
{{#is_alert}}
:oom: *OOMKilled*
*Namespace:* `{{kube_namespace.name}}`
*Container:* `{{kube_container_name.name}}`
{{/is_alert}}

${local.slack_handle}
EOT

  monitor_name = "[${upper(var.environment)}] OOMKilled 감지"
  monitor_tags = concat([
    "env:${var.environment}",
    "cluster:${var.cluster_name}",
    "managed_by:terraform",
    "source:devops-configs",
  ], var.notification_tags)
  pod_restart_query = format("sum(last_%dm):sum:oom_kill.oom_process.count{cluster_name:%s} by {kube_namespace,kube_container_name}.as_count() > %d", var.monitor_evaluation_window_min, var.cluster_name, var.monitor_restart_threshold)
  slack_handle      = var.slack_account_name == "" ? format("@slack-%s", trimprefix(var.slack_channel_name, "#")) : format("@slack-%s-%s", var.slack_account_name, trimprefix(var.slack_channel_name, "#"))
}
