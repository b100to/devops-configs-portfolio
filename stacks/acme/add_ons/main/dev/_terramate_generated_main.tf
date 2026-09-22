// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

module "addons" {
  cluster_endpoint          = var.cluster_endpoint
  cluster_name              = var.cluster_name
  cluster_version           = var.cluster_version
  eks_addons                = local.eks_addons_with_config
  enable_aws_efs_csi_driver = var.enable_aws_efs_csi_driver
  oidc_provider_arn         = var.oidc_provider_arn
  source                    = "aws-ia/eks-blueprints-addons/aws"
  tags                      = local.common_tags
  version                   = "~> 1.22.0"
}
