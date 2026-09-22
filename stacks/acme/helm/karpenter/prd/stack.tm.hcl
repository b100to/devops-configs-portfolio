stack {
  name        = "acme_helm_karpenter_v2_prd"
  id          = "acme_helm_karpenter_v2_prd"
  description = "helm karpenter"
  tags        = ["stack", "aws", "acme", "helm", "karpenter", "v2", "prd"]
  after = [
    "tag:prd:eks",
  ]
}

input "cluster_name" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_prd"
  value         = outputs.cluster_name.value
  mock          = "MOCK"
}


input "cluster_endpoint" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_prd"
  value         = outputs.cluster_endpoint.value
  mock          = "MOCK"
}


input "oidc_provider_arn" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_prd"
  value         = outputs.oidc_provider_arn.value
  mock          = "MOCK"
}


input "cluster_certificate_authority_data" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_prd"
  value         = outputs.cluster_certificate_authority_data.value
  mock          = "MOCK"
}


input "cluster_version" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_prd"
  value         = outputs.cluster_version.value
  mock          = "MOCK"
}
