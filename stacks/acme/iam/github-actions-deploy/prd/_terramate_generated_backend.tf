// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "s3" {
    bucket  = "acme-tfstate-prd"
    encrypt = true
    key     = "acme/iam/github-actions-deploy/prd/terraform.tfstate"
    profile = "prd"
    region  = "ap-northeast-2"
  }
}
