generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      loki_s3_buckets = {
        chunk = {
          name   = "${var.cluster_name}-loki-chunk"
          suffix = "chunk"
        }
        ruler = {
          name   = "${var.cluster_name}-loki-ruler"
          suffix = "ruler"
        }
        admin = {
          name   = "${var.cluster_name}-loki-admin"
          suffix = "admin"
        }
      }

      s3_common_config = {
        control_object_ownership = true
        object_ownership         = "BucketOwnerEnforced"

        versioning = {
          enabled = var.s3_versioning_enabled
        }
        server_side_encryption_configuration = {
          rule = {
            apply_server_side_encryption_by_default = {
              sse_algorithm = var.sse_algorithm
            }
          }
        }
      }
    }
  }
}