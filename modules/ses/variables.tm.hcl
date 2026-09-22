generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "environment" {
      description = "Environment name (dev/prd)"
      type        = string
    }

    variable "domain" {
      description = "SES domain to verify (e.g. dev.acme.example)"
      type        = string
    }

    variable "route53_zone_id" {
      description = "Route53 hosted zone ID for the domain"
      type        = string
    }

    variable "smtp_from_email" {
      description = "Default FROM email address (e.g. no-reply@dev.acme.example)"
      type        = string
    }

    variable "secret_name" {
      description = "Secrets Manager secret name for SMTP credentials"
      type        = string
      default     = ""
    }
  }
}
