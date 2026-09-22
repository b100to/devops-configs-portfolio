// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "environment" {
  description = "Environment name (dev/prd)"
  type        = string
}
variable "account_id" {
  description = "AWS Account ID"
  type        = string
}
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}
variable "slack_bot_token_secret_name" {
  default     = "cloudtrail/slack-bot-token"
  description = "AWS Secrets Manager secret name for Slack bot token"
  type        = string
}
variable "slack_channel" {
  description = "Slack channel ID for notifications"
  type        = string
}
variable "nodepools_config" {
  default     = "[{\"name\":\"base\",\"limits\":{\"cpu\":\"8\"}}]"
  description = "JSON array of Karpenter NodePools to scale [{name, limits}]"
  type        = string
}
variable "scale_up_schedule" {
  default     = "cron(0 8 ? * * *)"
  description = "Cron expression for scale-up (KST timezone)"
  type        = string
}
variable "scale_down_schedule" {
  default     = "cron(0 0 ? * * *)"
  description = "Cron expression for scale-down (KST timezone)"
  type        = string
}
