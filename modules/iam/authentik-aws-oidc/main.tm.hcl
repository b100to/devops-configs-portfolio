generate_hcl "_terramate_generated_main.tf" {
  content {
    locals {
      # "https://sso.acme.example/application/o/aws-cli/" -> "sso.acme.example/application/o/aws-cli/"
      oidc_provider_host = replace(var.oidc_provider_url, "https://", "")
    }

    # IAM OIDC Identity Provider (authentik)
    resource "aws_iam_openid_connect_provider" "authentik" {
      url             = var.oidc_provider_url
      client_id_list  = var.oidc_client_ids
      thumbprint_list = var.oidc_thumbprints
      tags            = global.tags
    }

    # devops-admin -> AdministratorAccess
    # Note: AWS IAM OIDC does NOT support custom claims (like "groups") in trust policy conditions.
    # Group-based access control is enforced at the authentik application level instead.
    # The sub claim (email) is used here to restrict to the allowed domain.
    resource "aws_iam_role" "oidc_admin" {
      name = var.admin_role_name

      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = "sts:AssumeRoleWithWebIdentity"
            Principal = {
              Federated = aws_iam_openid_connect_provider.authentik.arn
            }
            Condition = merge(
              {
                StringEquals = {
                  "${local.oidc_provider_host}:aud" = var.oidc_client_ids[0]
                }
                StringLike = {
                  "${local.oidc_provider_host}:sub" = var.allowed_sub_pattern
                }
              },
              length(var.allowed_source_ips) > 0 ? {
                IpAddress = {
                  "aws:SourceIp" = var.allowed_source_ips
                }
              } : {}
            )
          }
        ]
      })

      max_session_duration = var.max_session_duration
      tags                 = global.tags
    }

    resource "aws_iam_role_policy_attachment" "oidc_admin" {
      for_each = toset(var.admin_policy_arns)

      role       = aws_iam_role.oidc_admin.name
      policy_arn = each.value
    }

    # developer -> environment-specific policy
    resource "aws_iam_role" "oidc_developer" {
      name = var.developer_role_name

      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = "sts:AssumeRoleWithWebIdentity"
            Principal = {
              Federated = aws_iam_openid_connect_provider.authentik.arn
            }
            Condition = merge(
              {
                StringEquals = {
                  "${local.oidc_provider_host}:aud" = var.oidc_client_ids[0]
                }
                StringLike = {
                  "${local.oidc_provider_host}:sub" = var.allowed_sub_pattern
                }
              },
              length(var.allowed_source_ips) > 0 ? {
                IpAddress = {
                  "aws:SourceIp" = var.allowed_source_ips
                }
              } : {}
            )
          }
        ]
      })

      max_session_duration = var.max_session_duration
      tags                 = global.tags
    }

    resource "aws_iam_role_policy_attachment" "oidc_developer" {
      for_each = toset(var.developer_policy_arns)

      role       = aws_iam_role.oidc_developer.name
      policy_arn = each.value
    }
  }
}
