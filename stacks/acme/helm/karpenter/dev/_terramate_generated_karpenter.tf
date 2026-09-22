// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "aws_availability_zones" "available" {
}
module "karpenter" {
  cluster_name = local.eks_cluster_name
  depends_on = [
    data.aws_availability_zones.available,
  ]
  enable_irsa           = local.enable_irsa_integration
  enable_pod_identity   = local.enable_pod_identity_association
  enable_v1_permissions = local.enable_karpenter_v1_permissions
  iam_policy_statements = [
    {
      actions = [
        "iam:ListInstanceProfiles",
      ]
      resources = [
        "*",
      ]
      sid = "AllowInstanceProfileGarbageCollection"
    },
  ]
  irsa_oidc_provider_arn            = local.irsa_oidc_provider_arn
  node_iam_role_additional_policies = local.node_iam_policies
  source                            = "terraform-aws-modules/eks/aws//modules/karpenter"
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
  version = "~> 20.35.0"
}
module "karpenter_disabled" {
  create = local.enable_karpenter_provisioner
  depends_on = [
    data.aws_availability_zones.available,
  ]
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.35.0"
}
resource "helm_release" "karpenter" {
  chart            = var.karpenter.chart
  create_namespace = var.karpenter.create_namespace
  depends_on = [
    module.karpenter,
    module.karpenter_disabled,
    data.aws_availability_zones.available,
  ]
  name       = local.karpenter_helm_release_name
  namespace  = var.karpenter.namespace
  repository = var.karpenter.repository
  timeout    = var.karpenter.timeout
  values     = local.karpenter_helm_values
  version    = var.karpenter.version
  wait       = var.karpenter.wait
}
