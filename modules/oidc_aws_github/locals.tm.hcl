generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      common_tags = global.tags
    }
  }
}
