generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "enable_aws_efs_csi_driver" {
      description = "EFS CSI Driver 설치 여부 (Helm + IRSA 자동 생성)"
      type        = bool
      default     = false
    }

    # 기존 EKS 애드온 변수 선언
    variable "eks_addons" {
      description = "Map of EKS add-ons to be installed."
      type        = map(any)
      default = {
        vpc-cni                = {}
        kube-proxy             = {}
        eks-pod-identity-agent = {}
      }
    }

    # 기본 리소스 설정을 변수로 정의
    variable "enable_prefix_delegation" {
      description = "VPC CNI prefix delegation 활성화 여부 (노드당 IP 용량 증가)"
      type        = bool
      default     = false
    }

    variable "addon_resources" {
      description = "리소스 설정 (CPU/메모리 요청 및 제한)"
      type = map(object({
        cpu_request    = string
        memory_request = string
        cpu_limit      = string
        memory_limit   = string
      }))

      default = {
        vpc_cni = {
          cpu_request    = "15m"
          memory_request = "70Mi"
          cpu_limit      = "30m"
          memory_limit   = "100Mi"
        }
        kube_proxy = {
          cpu_request    = "20m"
          memory_request = "25Mi"
          cpu_limit      = "50m"
          memory_limit   = "50Mi"
        }
        pod_identity = {
          cpu_request    = "15m"
          memory_request = "25Mi"
          cpu_limit      = "30m"
          memory_limit   = "40Mi"
        }
      }
    }
  }
}
