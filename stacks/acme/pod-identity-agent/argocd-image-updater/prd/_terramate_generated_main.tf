// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_iam_role" "this" {
  assume_role_policy = local.assume_role_policy
  name               = local.role_name
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_policy" "this" {
  description = "Additional permissions for ${var.service_account}"
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
locals {
  pia_service_accounts = length(var.service_accounts) > 0 ? var.service_accounts : [
    var.service_account,
  ]
}
resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  for_each        = toset(local.pia_service_accounts)
  namespace       = var.namespace
  role_arn        = aws_iam_role.this.arn
  service_account = each.value
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
