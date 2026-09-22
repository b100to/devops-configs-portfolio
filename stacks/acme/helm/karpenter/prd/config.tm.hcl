globals {
  environment = "prd"
  account_id  = "222222222222"

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.8.0"

  namespace        = "karpenter"
  create_namespace = true
  wait             = false
  timeout          = 150
}