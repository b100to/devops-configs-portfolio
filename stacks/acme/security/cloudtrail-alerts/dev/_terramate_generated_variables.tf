// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "environment" {
  description = "Environment name (dev/prd)"
  type        = string
}
variable "account_id" {
  description = "AWS Account ID"
  type        = string
}
variable "slack_bot_token_secret_name" {
  default     = "cloudtrail/slack-bot-token"
  description = "AWS Secrets Manager secret name for Slack bot token"
  type        = string
}
variable "slack_channel" {
  description = "Slack channel ID or name to post alerts"
  type        = string
}
variable "s3_lifecycle_days" {
  default     = 90
  description = "Days to retain CloudTrail logs in S3 before deletion"
  type        = number
}
variable "trail_name" {
  default     = "acme-management-events"
  description = "CloudTrail trail name"
  type        = string
}
variable "allowed_ips" {
  default = [
  ]
  description = "Allowed IP CIDRs (company IPs). Events from other IPs will be flagged."
  type        = list(string)
}
