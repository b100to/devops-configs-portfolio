generate_hcl "_terramate_generated_main.tf" {
  content {
    resource "aws_iam_role" "this" {
      name               = local.role_name
      assume_role_policy = local.assume_role_policy
      tags               = global.tags
    }

    # 커스텀 정책 생성 및 연결
    resource "aws_iam_policy" "this" {
      name        = local.policy_name
      description = "Additional permissions for ${var.service_account}"
      policy      = local.policy
      tags        = global.tags
    }

    resource "aws_iam_role_policy_attachment" "this" {
      policy_arn = aws_iam_policy.this.arn
      role       = aws_iam_role.this.name
    }

    locals {
      pia_service_accounts = length(var.service_accounts) > 0 ? var.service_accounts : [var.service_account]
    }

    resource "aws_eks_pod_identity_association" "this" {
      for_each        = toset(local.pia_service_accounts)
      cluster_name    = var.cluster_name
      namespace       = var.namespace
      service_account = each.value
      role_arn        = aws_iam_role.this.arn
      tags            = global.tags
    }
  }
} 