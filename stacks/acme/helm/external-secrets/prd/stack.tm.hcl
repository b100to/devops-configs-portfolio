stack {
  name        = "acme_helm_external_secrets_v2_prd"
  id          = "acme_helm_external-secrets_v2_prd"
  description = "helm external-secrets"
  tags        = ["stack", "aws", "acme", "helm", "external_secrets", "v2", "prd"]
  after = [
    "tag:prd:manifests:karpenter",
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

input "cluster_certificate_authority_data" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_prd"
  value         = outputs.cluster_certificate_authority_data.value
  mock          = "MOCK"
}
