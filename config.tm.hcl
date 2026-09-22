globals {
  environment        = terramate.stack.path.basename
  region             = "ap-northeast-2"
  local_tfstate_path = "terraform.tfstate"

  terraform_version                  = "1.13.5"
  terraform_aws_provider_version     = "~> 6.28.0"
  terraform_k8s_provider_version     = "~> 2.38.0"
  terraform_helm_provider_version    = "~> 2.17.0"
  terraform_kubectl_provider_version = "~> 1.19.0"
  terraform_tls_provider_version     = "~> 4.1.0"
  terraform_datadog_provider_version = "~> 3.60.0"

  tags = {
    CreatedBy   = "terraform"
    Team        = "DevOps"
    Project     = tm_try(global.domain, "acme")
    Environment = global.environment
  }
}