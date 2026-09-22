generate_hcl "_terramate_generated_main.tf" {
  content {
    resource "aws_iam_saml_provider" "authentik" {
      name                   = var.saml_provider_name
      saml_metadata_document = var.saml_metadata_document
      tags                   = global.tags
    }

    resource "aws_iam_role" "authentik_admin" {
      name = var.role_name

      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = "sts:AssumeRoleWithSAML"
            Principal = {
              Federated = aws_iam_saml_provider.authentik.arn
            }
            Condition = {
              StringEquals = {
                "SAML:aud" = "https://signin.aws.amazon.com/saml"
              }
            }
          }
        ]
      })

      max_session_duration = var.max_session_duration
      tags                 = global.tags
    }

    resource "aws_iam_role_policy_attachment" "authentik_admin" {
      for_each = toset(var.policy_arns)

      role       = aws_iam_role.authentik_admin.name
      policy_arn = each.value
    }
  }
}
