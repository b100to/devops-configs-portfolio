// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "aws_iam_policy_document" "irsa_trust" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]
    effect = "Allow"
    principals {
      identifiers = [
        var.oidc_provider_arn,
      ]
      type = "Federated"
    }
    condition {
      test = "StringEquals"
      values = [
        "sts.amazonaws.com",
      ]
      variable = "${local.oidc_issuer}:aud"
    }
    condition {
      test = "StringEquals"
      values = [
        "system:serviceaccount:${var.namespace}:${var.service_account}",
      ]
      variable = "${local.oidc_issuer}:sub"
    }
  }
}
resource "aws_iam_role" "this" {
  assume_role_policy = data.aws_iam_policy_document.irsa_trust.json
  name               = local.role_name
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_policy" "this" {
  description = "IRSA permissions for ${var.service_account}"
  name        = local.policy_name
  policy      = local.policy
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role_policy_attachment" "this" {
  policy_arn = aws_iam_policy.this.arn
  role       = aws_iam_role.this.name
}
