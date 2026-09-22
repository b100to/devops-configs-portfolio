// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "saml_provider_name" {
  description = "IAM SAML Provider name in AWS"
  type        = string
}
variable "saml_metadata_document" {
  description = "SAML metadata XML downloaded from authentik provider metadata endpoint"
  type        = string
}
variable "role_name" {
  description = "IAM role name that will be assumed via SAML"
  type        = string
}
variable "policy_arns" {
  default = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]
  description = "Managed policy ARNs to attach to the IAM role"
  type        = list(string)
}
variable "max_session_duration" {
  default     = 14400
  description = "Maximum session duration in seconds for AssumeRoleWithSAML"
  type        = number
}
