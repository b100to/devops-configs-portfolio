// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

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
  default     = "authentik-oidc-admin"
  description = "IAM role name for devops-admin group"
  type        = string
}
variable "developer_role_name" {
  default     = "authentik-oidc-developer"
  description = "IAM role name for developer group"
  type        = string
}
variable "admin_policy_arns" {
  default = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]
  description = "Managed policy ARNs for admin role"
  type        = list(string)
}
variable "developer_policy_arns" {
  description = "Managed policy ARNs for developer role"
  type        = list(string)
}
variable "allowed_sub_pattern" {
  default     = "*@acme-corp.example"
  description = "Pattern for allowed sub claim (e.g. *@acme-corp.example)"
  type        = string
}
variable "allowed_source_ips" {
  default = [
  ]
  description = "Allowed source IP CIDRs for AssumeRoleWithWebIdentity (e.g. office IP)"
  type        = list(string)
}
variable "max_session_duration" {
  default     = 43200
  description = "Maximum session duration in seconds"
  type        = number
}
