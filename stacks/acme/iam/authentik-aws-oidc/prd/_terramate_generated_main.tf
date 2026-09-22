// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  oidc_provider_host = replace(var.oidc_provider_url, "https://", "")
}
resource "aws_iam_openid_connect_provider" "authentik" {
  client_id_list = var.oidc_client_ids
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
  thumbprint_list = var.oidc_thumbprints
  url             = var.oidc_provider_url
}
resource "aws_iam_role" "oidc_admin" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.authentik.arn
        }
        Condition = merge({
          StringEquals = {
            "${local.oidc_provider_host}:aud" = var.oidc_client_ids[0]
          }
          StringLike = {
            "${local.oidc_provider_host}:sub" = var.allowed_sub_pattern
          }
          }, length(var.allowed_source_ips) > 0 ? {
          IpAddress = {
            "aws:SourceIp" = var.allowed_source_ips
          }
        } : {})
      },
    ]
  })
  max_session_duration = var.max_session_duration
  name                 = var.admin_role_name
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role_policy_attachment" "oidc_admin" {
  for_each   = toset(var.admin_policy_arns)
  policy_arn = each.value
  role       = aws_iam_role.oidc_admin.name
}
resource "aws_iam_role" "oidc_developer" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.authentik.arn
        }
        Condition = merge({
          StringEquals = {
            "${local.oidc_provider_host}:aud" = var.oidc_client_ids[0]
          }
          StringLike = {
            "${local.oidc_provider_host}:sub" = var.allowed_sub_pattern
          }
          }, length(var.allowed_source_ips) > 0 ? {
          IpAddress = {
            "aws:SourceIp" = var.allowed_source_ips
          }
        } : {})
      },
    ]
  })
  max_session_duration = var.max_session_duration
  name                 = var.developer_role_name
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role_policy_attachment" "oidc_developer" {
  for_each   = toset(var.developer_policy_arns)
  policy_arn = each.value
  role       = aws_iam_role.oidc_developer.name
}
