// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

module "tfstate" {
  acl                      = var.acl
  bucket                   = local.name
  control_object_ownership = var.control_object_ownership
  object_ownership         = var.object_ownership
  source                   = "terraform-aws-modules/s3-bucket/aws"
  tags                     = local.tags
  version                  = "~> 4.6.0"
  versioning               = var.versioning
}
