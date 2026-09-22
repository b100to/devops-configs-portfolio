generate_hcl "_terramate_generated_outputs.tf" {
  content {
    output "iam_role_arn" {
      value = module.oidc_github.iam_role_arn
    }
    output "iam_role_name" {
      value = module.oidc_github.iam_role_name
    }
    output "oidc_provider_arn" {
      value = module.oidc_github.oidc_provider_arn
    }
  }
}