// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "aws_iam_openid_connect_provider" "this" {
  arn = var.oidc_provider_arn
}
locals {
  oidc_issuer = replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")
  policy      = file("${path.module}/policy.json")
  policy_name = "irsa-${var.service_account}-prd"
  role_name   = "irsa-${var.service_account}-prd"
}
