generate_hcl "_terramate_generated_variables.tf" {
  content {
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
      description = "AWS Secrets Manager secret name that contains DD_API_KEY and DD_APP_KEY (JSON)"
      type        = string
      default     = "eks/acme-main-v2-prd"
    }

    variable "datadog_site" {
      description = "Datadog site (datadoghq.com / datadoghq.eu / us3.datadoghq.com 등)"
      type        = string
      default     = "datadoghq.com"
    }
  }
}
