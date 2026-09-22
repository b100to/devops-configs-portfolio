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

    variable "secret_name" {
      description = "Secrets Manager secret name for slack-agent config"
      type        = string
      default     = "slack-agent/config"
    }

    variable "zai_model" {
      description = "z.ai model name"
      type        = string
      default     = "glm-4.5"
    }

    variable "dev_cross_account_role_arn" {
      description = "ARN of the cross-account role in dev for K8s/AWS access"
      type        = string
      default     = ""
    }
  }
}
