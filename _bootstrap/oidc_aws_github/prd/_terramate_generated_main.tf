// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

module "oidc_github" {
  github_repositories  = var.github_repositories
  iam_role_policy_arns = var.iam_role_policy_arns
  source               = "unfunco/oidc-github/aws"
  tags                 = local.common_tags
  version              = "~> 2.0.2"
}
