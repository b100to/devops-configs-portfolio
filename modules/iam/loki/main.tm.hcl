generate_hcl "_terramate_generated_main.tf" {
  content {
    # Loki Chunk 버킷
    module "s3_bucket_chunk" {
      source  = "terraform-aws-modules/s3-bucket/aws"
      version = "~> 4.6.0"

      bucket = local.loki_s3_buckets.chunk.name

      control_object_ownership = local.s3_common_config.control_object_ownership
      object_ownership         = local.s3_common_config.object_ownership

      # 공통 설정 적용
      versioning                           = local.s3_common_config.versioning
      server_side_encryption_configuration = local.s3_common_config.server_side_encryption_configuration

      tags = merge(global.tags, {
        Name      = "Loki Chunk Bucket"
        Component = "loki-storage"
      })
    }

    # Loki Ruler 버킷
    module "s3_bucket_ruler" {
      source  = "terraform-aws-modules/s3-bucket/aws"
      version = "~> 4.6.0"

      bucket = local.loki_s3_buckets.ruler.name

      control_object_ownership = local.s3_common_config.control_object_ownership
      object_ownership         = local.s3_common_config.object_ownership

      # 공통 설정 적용
      versioning                           = local.s3_common_config.versioning
      server_side_encryption_configuration = local.s3_common_config.server_side_encryption_configuration

      tags = merge(global.tags, {
        Name      = "Loki Ruler Bucket"
        Component = "loki-storage"
      })
    }

    # Loki Admin 버킷
    module "s3_bucket_admin" {
      source  = "terraform-aws-modules/s3-bucket/aws"
      version = "~> 4.6.0"

      bucket = local.loki_s3_buckets.admin.name

      control_object_ownership = local.s3_common_config.control_object_ownership
      object_ownership         = local.s3_common_config.object_ownership

      # 공통 설정 적용
      versioning                           = local.s3_common_config.versioning
      server_side_encryption_configuration = local.s3_common_config.server_side_encryption_configuration

      tags = merge(global.tags, {
        Name      = "Loki Admin Bucket"
        Component = "loki-storage"
      })
    }
  }
}