// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "environment" {
  description = "Environment name (dev/prd)"
  type        = string
}
variable "account_id" {
  description = "AWS Account ID (for Secrets Manager data source)"
  type        = string
}
variable "cluster_name" {
  description = "EKS cluster name used as cluster_name tag in Datadog metrics"
  type        = string
}
variable "datadog_secret_name" {
  default     = "eks/acme-main-v2-prd"
  description = "AWS Secrets Manager secret name that contains DD_API_KEY and DD_APP_KEY (JSON)"
  type        = string
}
variable "datadog_site" {
  default     = "datadoghq.com"
  description = "Datadog site (datadoghq.com / datadoghq.eu / us3.datadoghq.com 등)"
  type        = string
}
variable "slack_account_name" {
  default     = ""
  description = "Datadog Slack integration account name. 공란(\"\") 이면 `@slack-<channel>` 형태 사용 (workspace 단일인 경우 권장). Datadog 에 여러 workspace 등록 시에만 설정."
  type        = string
}
variable "slack_channel_name" {
  description = "Slack channel (leading #), 예: #alert-prd"
  type        = string
}
variable "monitor_evaluation_window_min" {
  default     = 5
  description = "Pod restart 감지 윈도우 (분)"
  type        = number
}
variable "monitor_priority" {
  default     = 3
  description = "Datadog monitor priority (1=highest, 5=lowest). pod restart 노이즈 가능성 고려해 기본 3"
  type        = number
}
variable "monitor_restart_threshold" {
  default     = 0
  description = "해당 윈도우 내 restart 증가량이 이 값을 초과하면 alert (0 = 한 번이라도 restart 시 alert)"
  type        = number
}
variable "notification_tags" {
  default = [
  ]
  description = "Datadog monitor 에 추가로 붙일 태그"
  type        = list(string)
}
