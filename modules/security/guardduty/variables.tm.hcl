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

    variable "finding_publishing_frequency" {
      description = "Frequency for publishing GuardDuty findings (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)"
      type        = string
      default     = "FIFTEEN_MINUTES"
    }
  }
}
