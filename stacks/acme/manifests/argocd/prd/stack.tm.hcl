stack {
  name = "acme_manifests_argocd_v2_prd"
  id   = "acme_manifests_argocd_v2_prd"
  tags = ["stack", "aws", "acme", "manifests", "argocd", "v2", "prd"]
  after = [
    "tag:prd:helm:argocd"
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


input "cluster_version" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_prd"
  value         = outputs.cluster_version.value
  mock          = "MOCK"
}
