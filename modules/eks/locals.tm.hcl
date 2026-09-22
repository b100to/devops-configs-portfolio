generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      common_tags = global.tags

      name = tm_join("-", [global.domain, "main", global.version, global.environment]) // The name of the resource

      vpc_id = var.vpc_id // The VPC ID

      // 원래 private_subnet_ids 정의를 주석 처리
      // subnet_ids               = var.private_subnet_ids // The subnet IDs

      // 기존 클러스터와 일치하도록 명시적으로 서브넷 IDs 설정 (데이터 조회 방식으로 변경)
      subnet_ids = var.private_subnet_ids

      control_plane_subnet_ids = var.intra_subnet_ids // The control plane subnet IDs

      endpoint_public_access                   = true
      enable_cluster_creator_admin_permissions = false
      security_group_tags                      = {}

      // 관리자 사용자 정의
      cluster_admins = var.cluster_admins

      // 반복문을 통해 access_entries 생성
      access_entries = merge(
        {
          for name, user in local.cluster_admins : name => {
            kubernetes_groups = []
            principal_arn     = "arn:aws:iam::${global.account_id}:user/${user.email}"
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
          }
        },
        {
          // authentik OIDC 역할 (aws-oidc.sh credential_process → kubectl 접근용)
          // SAML 역할(authentik-admin)은 AWS 콘솔 전용이므로 EKS access entry 불필요
          authentik_oidc_admin = {
            kubernetes_groups = []
            principal_arn     = "arn:aws:iam::${global.account_id}:role/authentik-oidc-admin"
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
          // developer 권한 분리: IAM 매핑(dev=PowerUser/prd=ReadOnly)과 정합
          // dev=Edit(워크로드 수정+exec 가능, RBAC 변경 불가) / prd=View(조회+로그만, exec 불가)
          authentik_oidc_developer = {
            kubernetes_groups = []
            principal_arn     = "arn:aws:iam::${global.account_id}:role/authentik-oidc-developer"
            policy_associations = {
              developer_policy = {
                policy_arn = global.environment == "dev" ? "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" : "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
                access_scope = {
                  type       = "cluster"
                  namespaces = null
                }
              }
            }
          }
          // GitHub Actions CI/CD 역할 (Terraform helm 스택 배포용)
          github_actions = {
            kubernetes_groups = []
            principal_arn     = "arn:aws:iam::${global.account_id}:role/GitHubActions"
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
        },
        // dev-scaler Lambda 역할 (dev 환경 오프시간 자동 스케일링용)
        global.environment == "dev" ? {
          dev_scaler_lambda = {
            kubernetes_groups = []
            principal_arn     = "arn:aws:iam::${global.account_id}:role/dev-scaler-lambda-dev-role"
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
        } : {}
      )

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
              // cpu limit 미지정: Fargate pod cap(0.25vCPU)이 상한 역할.
              // 기존 "50"(50코어)은 오타로 사실상 무제한 — 50m 등으로 좁히면 DNS 버스트 스로틀 위험
              limits = {
                memory = "60Mi"
              }
            }
          })
          tolerations = [{
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          }]
          topology_spread_constraints = [{
            max_skew           = 1
            topology_key       = "topology.kubernetes.io/zone"
            when_unsatisfiable = "ScheduleAnyway"
            label_selector = {
              match_labels = {
                k8s-app = "kube-dns"
              }
            }
          }]
        }
      }

      node_sg_karpenter_tags = {
        "karpenter.sh/discovery" = local.name
      }

      # Fargate 프로필 정의
      fargate_profiles_config = merge(
        {
          karpenter = {
            name = "karpenter"
            selectors = [{
              namespace = "karpenter"
              labels = {
                CriticalAddonsOnly = "true"
              }
            }]
            subnet_ids = local.subnet_ids
            tags = merge(
              local.common_tags,
              local.node_sg_karpenter_tags,
              {
                "Name" = "${local.name}-karpenter-fargate"
            })
          }
          coredns = {
            name = "coredns"
            selectors = [{
              namespace = "kube-system"
              labels = {
                "k8s-app" = "kube-dns"
              }
            }]
            subnet_ids = local.subnet_ids
            tags       = local.common_tags
          }
        }
      )

      node_security_group_tags = merge(
        local.common_tags,
        local.node_sg_karpenter_tags
      )

      control_plane_sg_id = "sg-0000000000000002"

    }
  }
}