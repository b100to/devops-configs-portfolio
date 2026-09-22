generate_hcl "_terramate_generated_karpenter.tf" {
  content {
    data "aws_availability_zones" "available" {}
    module "karpenter" {
      source  = "terraform-aws-modules/eks/aws//modules/karpenter"
      version = "~> 20.35.0"

      cluster_name = local.eks_cluster_name

      enable_v1_permissions = local.enable_karpenter_v1_permissions

      # Instance Profile GC를 위한 추가 권한 (v1 모듈에 누락됨)
      iam_policy_statements = [
        {
          sid       = "AllowInstanceProfileGarbageCollection"
          actions   = ["iam:ListInstanceProfiles"]
          resources = ["*"]
        }
      ]
      # EKS Fargate currently does not support Pod Identity
      enable_pod_identity    = local.enable_pod_identity_association
      enable_irsa            = local.enable_irsa_integration
      irsa_oidc_provider_arn = local.irsa_oidc_provider_arn
      # irsa_namespace_service_accounts = ["kube-system/karpenter"]

      # Used to attach additional IAM policies to the Karpenter node IAM role
      node_iam_role_additional_policies = local.node_iam_policies

      tags = global.tags

      depends_on = [
        data.aws_availability_zones.available
      ]
    }

    module "karpenter_disabled" {
      source  = "terraform-aws-modules/eks/aws//modules/karpenter"
      version = "~> 20.35.0"

      create = local.enable_karpenter_provisioner

      depends_on = [
        data.aws_availability_zones.available
      ]
    }

    resource "helm_release" "karpenter" {
      name = local.karpenter_helm_release_name

      repository = var.karpenter.repository
      chart      = var.karpenter.chart
      version    = var.karpenter.version

      namespace        = var.karpenter.namespace
      create_namespace = var.karpenter.create_namespace

      wait    = var.karpenter.wait
      timeout = var.karpenter.timeout

      values = local.karpenter_helm_values

      depends_on = [
        module.karpenter,
        module.karpenter_disabled,
        data.aws_availability_zones.available
      ]
    }
  }
}