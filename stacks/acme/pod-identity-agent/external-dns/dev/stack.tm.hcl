stack {
  name = "acme_pod_identity_agent_external_dns_v2_dev"
  id   = "acme_pod-identity-agent_external-dns_v2_dev"
  tags = ["stack", "pod_identity_agent", "pia", "external_dns", "ed", "v2", "dev"]

  after = [
    "tag:dev:manifests:argocd",
  ]
}

input "cluster_name" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_dev"
  value         = outputs.cluster_name.value
  mock          = "MOCK"
}