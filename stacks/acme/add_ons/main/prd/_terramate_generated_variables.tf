// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "enable_aws_efs_csi_driver" {
  default     = false
  description = "EFS CSI Driver 설치 여부 (Helm + IRSA 자동 생성)"
  type        = bool
}
variable "eks_addons" {
  default = {
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }
  description = "Map of EKS add-ons to be installed."
  type        = map(any)
}
variable "enable_prefix_delegation" {
  default     = false
  description = "VPC CNI prefix delegation 활성화 여부 (노드당 IP 용량 증가)"
  type        = bool
}
variable "addon_resources" {
  default = {
    kube_proxy = {
      cpu_limit      = "50m"
      cpu_request    = "20m"
      memory_limit   = "50Mi"
      memory_request = "25Mi"
    }
    pod_identity = {
      cpu_limit      = "30m"
      cpu_request    = "15m"
      memory_limit   = "40Mi"
      memory_request = "25Mi"
    }
    vpc_cni = {
      cpu_limit      = "30m"
      cpu_request    = "15m"
      memory_limit   = "100Mi"
      memory_request = "70Mi"
    }
  }
  description = "리소스 설정 (CPU/메모리 요청 및 제한)"
  type = map(object({
    cpu_request    = string
    memory_request = string
    cpu_limit      = string
    memory_limit   = string
  }))
}
