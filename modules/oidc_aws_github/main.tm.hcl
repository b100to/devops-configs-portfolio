generate_hcl "_terramate_generated_main.tf" {
  content {
    module "oidc_github" {
      source  = "unfunco/oidc-github/aws"
      version = "~> 2.0.2"

      github_repositories  = var.github_repositories
      iam_role_policy_arns = var.iam_role_policy_arns
      tags                 = local.common_tags
    }
  }
}

