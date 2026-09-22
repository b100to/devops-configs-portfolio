generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "github_repositories" {
      description = "GitHub organization/repository names authorized to assume the role."
      type        = list(string)
      default = [
        "AcmeCorp/devops-configs"
      ]
    }

    variable "iam_role_policy_arns" {
      description = "IAM policy ARNs to attach to the IAM role."
      type        = list(string)
      default = [
        "arn:aws:iam::aws:policy/AdministratorAccess"
      ]
    }
  }
}
