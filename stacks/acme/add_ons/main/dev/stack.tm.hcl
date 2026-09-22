stack {
  name = "acme_eks_add_ons_main_v2_dev"
  id   = "acme_eks_${tm_replace("add_ons", "_", "-")}_main_v2_dev"
  tags = ["stack", "acme", "add_ons", "main", "v2", "dev"]

  after = [
    "tag:dev:manifests:karpenter",
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


input "oidc_provider_arn" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_dev"
  value         = outputs.oidc_provider_arn.value
  mock          = "MOCK"
}


input "cluster_certificate_authority_data" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_dev"
  value         = outputs.cluster_certificate_authority_data.value
  mock          = "MOCK"
}


input "cluster_version" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_dev"
  value         = outputs.cluster_version.value
  mock          = "MOCK"
}