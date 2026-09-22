generate_hcl "_terramate_generated_outputs.tf" {
  content {
    output "saml_provider_arn" {
      description = "ARN of AWS IAM SAML provider"
      value       = aws_iam_saml_provider.authentik.arn
    }

    output "role_arn" {
      description = "ARN of AWS IAM role for authentik SAML login"
      value       = aws_iam_role.authentik_admin.arn
    }
  }
}
