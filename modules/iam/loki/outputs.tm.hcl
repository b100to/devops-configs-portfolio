generate_hcl "_terramate_generated_outputs.tf" {
  content {
    output "loki_s3_buckets" {
      description = "Loki S3 버킷 이름 목록"
      value = {
        chunk = module.s3_bucket_chunk.s3_bucket_id
        ruler = module.s3_bucket_ruler.s3_bucket_id
        admin = module.s3_bucket_admin.s3_bucket_id
      }
    }

    output "loki_s3_bucket_arns" {
      description = "Loki S3 버킷 ARN 목록"
      value = {
        chunk = module.s3_bucket_chunk.s3_bucket_arn
        ruler = module.s3_bucket_ruler.s3_bucket_arn
        admin = module.s3_bucket_admin.s3_bucket_arn
      }
    }

    output "loki_s3_bucket_region" {
      description = "Loki S3 버킷 리전"
      value       = module.s3_bucket_chunk.s3_bucket_region
    }
  }
}