generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "oidc_provider_url" {
      description = "OIDC provider URL (e.g. https://sso.acme.example/application/o/aws-cli/)"
      type        = string
    }

    variable "oidc_client_ids" {
      description = "OIDC client IDs (audience)"
      type        = list(string)
    }

    variable "oidc_thumbprints" {
      description = "TLS certificate thumbprints for the OIDC provider"
      type        = list(string)
    }

    variable "admin_role_name" {
      description = "IAM role name for devops-admin group"
      type        = string
      default     = "authentik-oidc-admin"
    }

    variable "developer_role_name" {
      description = "IAM role name for developer group"
      type        = string
      default     = "authentik-oidc-developer"
    }

    variable "admin_policy_arns" {
      description = "Managed policy ARNs for admin role"
      type        = list(string)
      default = [
        "arn:aws:iam::aws:policy/AdministratorAccess",
      ]
    }

    variable "developer_policy_arns" {
      description = "Managed policy ARNs for developer role"
      type        = list(string)
    }

    variable "allowed_sub_pattern" {
      description = "Pattern for allowed sub claim (e.g. *@acme-corp.example)"
      type        = string
      default     = "*@acme-corp.example"
    }

    variable "allowed_source_ips" {
      description = "Allowed source IP CIDRs for AssumeRoleWithWebIdentity (e.g. office IP)"
      type        = list(string)
      default     = []
    }

    variable "max_session_duration" {
      description = "Maximum session duration in seconds"
      type        = number
      default     = 43200
    }
  }
}
