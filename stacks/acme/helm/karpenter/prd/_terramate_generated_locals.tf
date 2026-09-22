// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  eks_cluster_endpoint            = var.cluster_endpoint
  eks_cluster_name                = var.cluster_name
  enable_irsa_integration         = true
  enable_karpenter_provisioner    = false
  enable_karpenter_v1_permissions = true
  enable_pod_identity_association = false
  irsa_oidc_provider_arn          = var.oidc_provider_arn
  karpenter_helm_release_name     = "karpenter"
  karpenter_helm_values = [
    templatefile("${path.root}/values.yaml", local.karpenter_template_vars),
  ]
  karpenter_template_vars = {
    cluster_name     = local.eks_cluster_name
    cluster_endpoint = local.eks_cluster_endpoint
    queue_name       = module.karpenter.queue_name
    iam_role_arn     = module.karpenter.iam_role_arn
  }
  node_iam_policies = {
    AmazonS3FullAccess           = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    SecretsManagerReadWrite      = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  }
}
