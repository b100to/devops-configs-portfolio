// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "s3" {
    bucket  = "acme-tfstate-prd"
    encrypt = true
    key     = "acme/pod-identity-agent/aws-load-balancer-controller/v2/prd/terraform.tfstate"
    profile = "prd"
    region  = "ap-northeast-2"
  }
}
