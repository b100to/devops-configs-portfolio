generate_hcl "_terramate_generated_main.tf" {
  content {
    module "addons" {
      source  = "aws-ia/eks-blueprints-addons/aws"
      version = "~> 1.22.0"

      cluster_name      = var.cluster_name
      cluster_endpoint  = var.cluster_endpoint
      cluster_version   = var.cluster_version
      oidc_provider_arn = var.oidc_provider_arn

      eks_addons = local.eks_addons_with_config

      # EFS CSI Driver (Helm + IRSA 자동 생성)
      enable_aws_efs_csi_driver = var.enable_aws_efs_csi_driver

      tags = local.common_tags
    }
  }
}