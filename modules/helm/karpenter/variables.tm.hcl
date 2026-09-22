generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "karpenter" {
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
      default = {
        repository       = "oci://public.ecr.aws/karpenter"
        chart            = "karpenter"
        version          = "1.7.4"
        namespace        = "karpenter"
        create_namespace = true
        wait             = false
        timeout          = 150
      }
    }
  }
}