// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "s3" {
    bucket  = "acme-tfstate-prd"
    encrypt = true
    key     = "acme/security/cloudtrail-alerts/prd/terraform.tfstate"
    profile = "prd"
    region  = "ap-northeast-2"
  }
}
