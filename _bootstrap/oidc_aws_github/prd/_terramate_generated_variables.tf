// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "github_repositories" {
  default = [
    "AcmeCorp/devops-configs",
  ]
  description = "GitHub organization/repository names authorized to assume the role."
  type        = list(string)
}
variable "iam_role_policy_arns" {
  default = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]
  description = "IAM policy ARNs to attach to the IAM role."
  type        = list(string)
}
