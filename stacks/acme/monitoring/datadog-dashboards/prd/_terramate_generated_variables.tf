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
