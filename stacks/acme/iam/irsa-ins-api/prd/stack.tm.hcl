stack {
  name = "acme_iam_irsa_ins-api_prd"
  id   = "acme_iam_irsa_ins-api_prd"
  tags = ["stack", "iam", "irsa", "venue", "ins-api", "prd"]
}

input "oidc_provider_arn" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_prd"
  value         = outputs.oidc_provider_arn.value
  mock          = "MOCK"
}
