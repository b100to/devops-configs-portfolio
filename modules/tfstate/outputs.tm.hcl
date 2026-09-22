generate_hcl "_terramate_generated_outputs.tf" {
  content {
    output "s3_bucket_arn" {
      value = module.tfstate.s3_bucket_arn
    }
    output "s3_bucket_id" {
      value = module.tfstate.s3_bucket_id
    }
    output "s3_bucket_bucket_domain_name" {
      value = module.tfstate.s3_bucket_bucket_domain_name
    }
    output "s3_bucket_bucket_regional_domain_name" {
      value = module.tfstate.s3_bucket_bucket_regional_domain_name
    }
    output "s3_bucket_hosted_zone_id" {
      value = module.tfstate.s3_bucket_hosted_zone_id
    }
    output "s3_bucket_region" {
      value = module.tfstate.s3_bucket_region
    }
    output "s3_directory_bucket_arn" {
      value = module.tfstate.s3_directory_bucket_arn
    }
    output "s3_directory_bucket_name" {
      value = module.tfstate.s3_directory_bucket_name
    }
  }
}
