# # Generate '_terramate_generated_backend.tf' in each stack for Local File-System
# generate_hcl "_terramate_generated_backend.tf" {
#   condition = global.isLocal == true

#   content {
#     terraform {

#       backend "local" {
#         path = global.local_tfstate_path
#       }
#     }
#   }
# }

# Generate '_terramate_generated_backend.tf' in each stack for Remote S3
generate_hcl "_terramate_generated_backend.tf" {
  content {
    terraform {

      backend "s3" {
        region  = global.region
        bucket  = tm_join("-", [global.domain, "tfstate", global.environment])
        key     = "${tm_replace("${terramate.stack.id}", "_", "/")}/terraform.tfstate"
        encrypt = true
        profile = global.environment
      }
    }
  }
}