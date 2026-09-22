stack {
  name = "acme_manifests_karpenter_v2_dev"
  id   = "acme_manifests_karpenter_v2_dev"
  tags = ["stack", "aws", "acme", "manifests", "karpenter", "v2", "dev"]
  after = [
    "tag:dev:eks",
    "tag:dev:helm:karpenter",
  ]
}

input "node_iam_role_arn" {
  backend       = "default"
  from_stack_id = "acme_helm_karpenter_v2_dev"
  value         = outputs.node_iam_role_arn.value
  mock          = "MOCK"
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


input "cluster_version" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_dev"
  value         = outputs.cluster_version.value
  mock          = "MOCK"
}