generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      # EKS Cluster Configuration
      eks_cluster_name     = var.cluster_name
      eks_cluster_endpoint = var.cluster_endpoint

      # IAM & Authentication Configuration
      enable_karpenter_v1_permissions = true
      enable_pod_identity_association = false
      enable_irsa_integration         = true
      irsa_oidc_provider_arn          = var.oidc_provider_arn

      # Node IAM Policies
      node_iam_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        SecretsManagerReadWrite      = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
        AmazonS3FullAccess           = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
      }

      # Karpenter Configuration
      enable_karpenter_provisioner = false

      # Helm & Values Configuration
      karpenter_helm_release_name = tm_replace("karpenter", "_", "-")
      karpenter_helm_values       = [templatefile("${path.root}/values.yaml", local.karpenter_template_vars)]

      # Template Variables for Karpenter
      karpenter_template_vars = {
        cluster_name     = local.eks_cluster_name
        cluster_endpoint = local.eks_cluster_endpoint
        queue_name       = module.karpenter.queue_name
        iam_role_arn     = module.karpenter.iam_role_arn
      }
    }
  }
}