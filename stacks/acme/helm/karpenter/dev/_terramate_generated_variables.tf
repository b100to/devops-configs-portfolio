// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "karpenter" {
  default = {
    chart            = "karpenter"
    create_namespace = true
    namespace        = "karpenter"
    repository       = "oci://public.ecr.aws/karpenter"
    timeout          = 150
    version          = "1.7.4"
    wait             = false
  }
  description = "Karpenter Helm chart configuration"
  type = object({
    repository       = string
    chart            = string
    version          = string
    namespace        = string
    create_namespace = bool
    wait             = bool
    timeout          = number
  })
}
