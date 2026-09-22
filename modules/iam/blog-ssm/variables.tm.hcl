generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "role_name" {
      description = "IAM role name for the SSM-managed blog bastion"
      type        = string
      default     = "blog-ssm-role"
    }

    variable "instance_profile_name" {
      description = "IAM instance profile name attached to the blog EC2"
      type        = string
      default     = "blog-ssm-profile"
    }

    variable "session_log_group_name" {
      description = "CloudWatch log group name for SSM Session Manager session logs (audit)"
      type        = string
      default     = "/aws/ssm/session-logs/prd"
    }

    variable "session_log_retention_days" {
      description = "Retention period (days) for session logs — ISMS 로그 보존기간"
      type        = number
      default     = 365
    }
  }
}
