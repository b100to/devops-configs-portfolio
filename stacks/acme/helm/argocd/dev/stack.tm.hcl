stack {
  name = "acme_helm_argocd_v2_dev"
  id   = "acme_helm_argocd_v2_dev"
  tags = ["stack", "aws", "acme", "helm", "argocd", "v2", "dev"]
  after = [
    "tag:dev:manifests:karpenter",
    "tag:dev:manifests:external_secrets",
  ]
}

input "cluster_name" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_dev"
  value         = outputs.cluster_name.value
  mock          = "MOCK"
}

input "cluster_endpoint" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_dev"
  value         = outputs.cluster_endpoint.value
  mock          = "MOCK"
}

input "cluster_certificate_authority_data" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_dev"
  value         = outputs.cluster_certificate_authority_data.value
  mock          = "MOCK"
}

