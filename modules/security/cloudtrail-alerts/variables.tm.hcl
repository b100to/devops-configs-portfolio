generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "environment" {
      description = "Environment name (dev/prd)"
      type        = string
    }

    variable "account_id" {
      description = "AWS Account ID"
      type        = string
    }

    variable "slack_bot_token_secret_name" {
      description = "AWS Secrets Manager secret name for Slack bot token"
      type        = string
      default     = "cloudtrail/slack-bot-token"
    }

    variable "slack_channel" {
      description = "Slack channel ID or name to post alerts"
      type        = string
    }

    variable "s3_lifecycle_days" {
      description = "Days to retain CloudTrail logs in S3 before deletion"
      type        = number
      default     = 90
    }

    variable "trail_name" {
      description = "CloudTrail trail name"
      type        = string
      default     = "acme-management-events"
    }

    variable "allowed_ips" {
      description = "Allowed IP CIDRs (company IPs). Events from other IPs will be flagged."
      type        = list(string)
      default     = []
    }
  }
}
