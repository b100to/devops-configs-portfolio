generate_hcl "_terramate_generated_main.tf" {
  content {
    # IRSA trust policy — OIDC issuer 기반 동적 condition key 사용
    data "aws_iam_policy_document" "irsa_trust" {
      statement {
        effect = "Allow"

        principals {
          type        = "Federated"
          identifiers = [var.oidc_provider_arn]
        }

        actions = ["sts:AssumeRoleWithWebIdentity"]

        condition {
          test     = "StringEquals"
          variable = "${local.oidc_issuer}:aud"
          values   = ["sts.amazonaws.com"]
        }

        condition {
          test     = "StringEquals"
          variable = "${local.oidc_issuer}:sub"
          values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
        }
      }
    }

    resource "aws_iam_role" "this" {
      name               = local.role_name
      assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
      tags               = global.tags
    }

    resource "aws_iam_policy" "this" {
      description = "IRSA permissions for ${var.service_account}"
      name        = local.policy_name
      policy      = local.policy
      tags        = global.tags
    }

    resource "aws_iam_role_policy_attachment" "this" {
      policy_arn = aws_iam_policy.this.arn
      role       = aws_iam_role.this.name
    }
  }
}
