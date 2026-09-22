generate_hcl "_terramate_generated_outputs.tf" {
  content {
    output "oidc_provider_arn" {
      description = "ARN of AWS IAM OIDC provider"
      value       = aws_iam_openid_connect_provider.authentik.arn
    }

    output "admin_role_arn" {
      description = "ARN of admin IAM role for OIDC login"
      value       = aws_iam_role.oidc_admin.arn
    }

    output "developer_role_arn" {
      description = "ARN of developer IAM role for OIDC login"
      value       = aws_iam_role.oidc_developer.arn
    }
  }
}
