// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_iam_saml_provider" "authentik" {
  name                   = var.saml_provider_name
  saml_metadata_document = var.saml_metadata_document
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role" "authentik_admin" {
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
      },
    ]
  })
  max_session_duration = var.max_session_duration
  name                 = var.role_name
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role_policy_attachment" "authentik_admin" {
  for_each   = toset(var.policy_arns)
  policy_arn = each.value
  role       = aws_iam_role.authentik_admin.name
}
