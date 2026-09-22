// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  addon_configs = {
    vpc-cni = jsonencode(merge({
      resources = {
        requests = {
          cpu    = var.addon_resources.vpc_cni.cpu_request
          memory = var.addon_resources.vpc_cni.memory_request
        }
        limits = {
          cpu    = var.addon_resources.vpc_cni.cpu_limit
          memory = var.addon_resources.vpc_cni.memory_limit
        }
      }
      }, var.enable_prefix_delegation ? {
      env = {
        ENABLE_PREFIX_DELEGATION = "true"
        WARM_PREFIX_TARGET       = "1"
      }
    } : {}))
    kube-proxy = jsonencode({
      resources = {
        requests = {
          cpu    = var.addon_resources.kube_proxy.cpu_request
          memory = var.addon_resources.kube_proxy.memory_request
        }
        limits = {
          cpu    = var.addon_resources.kube_proxy.cpu_limit
          memory = var.addon_resources.kube_proxy.memory_limit
        }
      }
    })
    eks-pod-identity-agent = jsonencode({
      resources = {
        requests = {
          cpu    = var.addon_resources.pod_identity.cpu_request
          memory = var.addon_resources.pod_identity.memory_request
        }
        limits = {
          cpu    = var.addon_resources.pod_identity.cpu_limit
          memory = var.addon_resources.pod_identity.memory_limit
        }
      }
    })
  }
  common_tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
  eks_addons_with_config = { for name, config in var.eks_addons : name => merge(config, {
    configuration_values = lookup(local.addon_configs, name, "")
    resolve_conflicts    = "OVERWRITE"
  }) }
}
