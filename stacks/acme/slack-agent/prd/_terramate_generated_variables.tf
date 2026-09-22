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
variable "secret_name" {
  default     = "slack-agent/config"
  description = "Secrets Manager secret name for slack-agent config"
  type        = string
}
variable "zai_model" {
  default     = "glm-4.5"
  description = "z.ai model name"
  type        = string
}
variable "dev_cross_account_role_arn" {
  default     = ""
  description = "ARN of the cross-account role in dev for K8s/AWS access"
  type        = string
}
