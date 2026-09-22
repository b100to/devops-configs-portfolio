stack {
  name = "acme_outline_prd"
  id   = "acme_outline_prd"
  tags = ["stack", "outline", "prd"]
}

input "oidc_provider_arn" {
  backend       = "default"
  from_stack_id = "acme_eks_main_v2_prd"
  value         = outputs.oidc_provider_arn.value
  mock          = "MOCK"
}
