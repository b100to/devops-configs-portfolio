// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  access_entries = merge({ for name, user in local.cluster_admins : name => {
    kubernetes_groups = [
    ]
    principal_arn = "arn:aws:iam::111111111111:user/${user.email}"
    policy_associations = {
      cluster_admin_policy = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = user.scope == "cluster" ? {
          type       = "cluster"
          namespaces = null
          } : {
          type       = "namespace"
          namespaces = user.namespaces
        }
      }
    }
    } }, {
    authentik_oidc_admin = {
      kubernetes_groups = [
      ]
      principal_arn = "arn:aws:iam::111111111111:role/authentik-oidc-admin"
      policy_associations = {
        cluster_admin_policy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "cluster"
            namespaces = null
          }
        }
      }
    }
    authentik_oidc_developer = {
      kubernetes_groups = [
      ]
      principal_arn = "arn:aws:iam::111111111111:role/authentik-oidc-developer"
      policy_associations = {
        developer_policy = {
          policy_arn = "dev" == "dev" ? "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" : "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type       = "cluster"
            namespaces = null
          }
        }
      }
    }
    github_actions = {
      kubernetes_groups = [
      ]
      principal_arn = "arn:aws:iam::111111111111:role/GitHubActions"
      policy_associations = {
        cluster_admin_policy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "cluster"
            namespaces = null
          }
        }
      }
    }
    }, "dev" == "dev" ? {
    dev_scaler_lambda = {
      kubernetes_groups = [
      ]
      principal_arn = "arn:aws:iam::111111111111:role/dev-scaler-lambda-dev-role"
      policy_associations = {
        cluster_admin_policy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "cluster"
            namespaces = null
          }
        }
      }
    }
  } : {})
  addons = {
    coredns = {
      configuration_values = jsonencode({
        computeType  = "Fargate"
        replicaCount = var.coredns_replica_count
        resources = {
          requests = {
            cpu    = "25m"
            memory = "30Mi"
          }
          limits = {
            memory = "60Mi"
          }
        }
      })
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
          effect   = "NoSchedule"
        },
      ]
      topology_spread_constraints = [
        {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector = {
            match_labels = {
              k8s-app = "kube-dns"
            }
          }
        },
      ]
    }
  }
  cluster_admins = var.cluster_admins
  common_tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
  control_plane_sg_id                      = "sg-0000000000000002"
  control_plane_subnet_ids                 = var.intra_subnet_ids
  enable_cluster_creator_admin_permissions = false
  endpoint_public_access                   = true
  fargate_profiles_config = merge({
    karpenter = {
      name = "karpenter"
      selectors = [
        {
          namespace = "karpenter"
          labels = {
            CriticalAddonsOnly = "true"
          }
        },
      ]
      subnet_ids = local.subnet_ids
      tags = merge(local.common_tags, local.node_sg_karpenter_tags, {
        "Name" = "${local.name}-karpenter-fargate"
      })
    }
    coredns = {
      name = "coredns"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "k8s-app" = "kube-dns"
          }
        },
      ]
      subnet_ids = local.subnet_ids
      tags       = local.common_tags
    }
  })
  name                     = "acme-main-v2-dev"
  node_security_group_tags = merge(local.common_tags, local.node_sg_karpenter_tags)
  node_sg_karpenter_tags = {
    "karpenter.sh/discovery" = local.name
  }
  security_group_tags = {}
  subnet_ids          = var.private_subnet_ids
  vpc_id              = var.vpc_id
}
