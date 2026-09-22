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

    variable "cluster_name" {
      description = "EKS cluster name"
      type        = string
    }

    variable "slack_bot_token_secret_name" {
      description = "AWS Secrets Manager secret name for Slack bot token"
      type        = string
      default     = "cloudtrail/slack-bot-token"
    }

    variable "slack_channel" {
      description = "Slack channel ID for notifications"
      type        = string
    }

    variable "nodepools_config" {
      description = "JSON array of Karpenter NodePools to scale [{name, limits}]"
      type        = string
      default     = "[{\"name\":\"base\",\"limits\":{\"cpu\":\"8\"}}]"
    }

    variable "scale_up_schedule" {
      description = "Cron expression for scale-up (KST timezone)"
      type        = string
      # 주말 포함 매일 08:00 기동
      default = "cron(0 8 ? * * *)"
    }

    variable "scale_down_schedule" {
      description = "Cron expression for scale-down (KST timezone)"
      type        = string
      # 주말 포함 매일 00:00 다운 (up과 동일하게 7일 on/off 사이클)
      default = "cron(0 0 ? * * *)"
    }
  }
}
