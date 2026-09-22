// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "s3" {
    bucket  = "acme-tfstate-dev"
    encrypt = true
    key     = "acme/helm/external-secrets/v2/dev/terraform.tfstate"
    profile = "dev"
    region  = "ap-northeast-2"
  }
}
