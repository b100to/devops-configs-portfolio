// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "role_name" {
  default     = "blog-ssm-role"
  description = "IAM role name for the SSM-managed blog bastion"
  type        = string
}
variable "instance_profile_name" {
  default     = "blog-ssm-profile"
  description = "IAM instance profile name attached to the blog EC2"
  type        = string
}
variable "session_log_group_name" {
  default     = "/aws/ssm/session-logs/prd"
  description = "CloudWatch log group name for SSM Session Manager session logs (audit)"
  type        = string
}
variable "session_log_retention_days" {
  default     = 365
  description = "Retention period (days) for session logs — ISMS 로그 보존기간"
  type        = number
}
