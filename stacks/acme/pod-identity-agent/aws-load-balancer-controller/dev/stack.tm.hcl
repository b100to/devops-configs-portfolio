stack {
  name = "acme_pod_identity_agent_aws_load_balancer_controller_v2_dev"
  id   = "acme_pod-identity-agent_aws-load-balancer-controller_v2_dev"
  tags = ["stack", "pod_identity_agent", "pia", "aws_load_balancer_controller", "albc", "v2", "dev"]

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