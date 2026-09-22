generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "kubernetes_version" {
      description = "Kubernetes version for the EKS cluster"
      type        = string
      default     = "1.35"
    }

    # 실제 모듈 핀은 main.tm.hcl의 version(리터럴 필수)이 결정.
    # 이 변수는 문서화용이므로 main.tm.hcl 버전업 시 함께 갱신할 것.
    variable "module_version" {
      description = "Version of the module. (informational — actual pin in main.tm.hcl)"
      type        = string
      default     = "~> 21.9.0"
    }

    variable "endpoint_public_access_cidrs" {
      description = "List of CIDR blocks for public access to the cluster endpoint."
      type        = list(string)
      default = [
        "0.0.0.0/0"
      ]
    }

    variable "cluster_admins" {
      description = "Map of cluster admin users (IAM-user 직접 연결은 레거시. 신규는 Authentik OIDC role 경유)"
      type = map(object({
        email  = string
        scope  = string
        groups = optional(list(string))
      }))
      # 레거시 IAM 유저 직접 연결 제거 (jaehoon.jang, jonggu.woo).
      # 클러스터 접근은 authentik-oidc-admin/developer role 경유로 일원화.
      default = {}
    }

    variable "security_group_rules" {
      description = "Map of security group rules"
      type = map(object({
        description                   = string
        protocol                      = string
        from_port                     = number
        to_port                       = number
        type                          = string
        self                          = optional(bool)
        source_cluster_security_group = optional(bool)
      }))
      default = {
        istio_http = {
          description = "Node to node ingress on HTTP port"
          protocol    = "tcp"
          from_port   = 80
          to_port     = 80
          type        = "ingress"
          self        = true
        }
      }
    }
    variable "coredns_replica_count" {
      description = "Number of replicas for CoreDNS"
      type        = number
      default     = 1
    }

    variable "cloudwatch_log_group_retention_in_days" {
      description = "Number of days to retain log events in CloudWatch log group"
      type        = number
      default     = 5
    }

    variable "enabled_log_types" {
      description = "List of control plane log types to enable (api, audit, authenticator, controllerManager, scheduler)"
      type        = list(string)
      default     = []
    }
  }
}
