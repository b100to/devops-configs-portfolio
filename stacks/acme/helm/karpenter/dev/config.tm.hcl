globals {
  environment = "dev"
  account_id  = "111111111111"

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.8.0"

  namespace        = "karpenter"
  create_namespace = true
  wait             = false
  timeout          = 150
}