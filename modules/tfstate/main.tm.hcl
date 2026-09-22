generate_hcl "_terramate_generated_main.tf" {
  content {

    module "tfstate" {
      source  = "terraform-aws-modules/s3-bucket/aws"
      version = "~> 4.6.0"

      bucket = local.name
      acl    = var.acl

      control_object_ownership = var.control_object_ownership
      object_ownership         = var.object_ownership

      versioning = var.versioning

      tags = local.tags
    }
  }
}
