generate_hcl "_terramate_generated_locals.tf" {
  content {
    # EKS OIDC provider URL 조회 (trust policy condition key 구성용)
    data "aws_iam_openid_connect_provider" "this" {
      arn = var.oidc_provider_arn
    }

    locals {
      role_name   = "irsa-${var.service_account}-${global.environment}"
      policy_name = "irsa-${var.service_account}-${global.environment}"
      policy      = file("${path.module}/policy.json")

      # "https://oidc.eks.ap-northeast-2.amazonaws.com/id/XXX" -> "oidc.eks.ap-northeast-2.amazonaws.com/id/XXX"
      oidc_issuer = replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")
    }
  }
}
