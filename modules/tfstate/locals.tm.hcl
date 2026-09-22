generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      name = tm_join("-", ["acme", "tfstate", global.environment])

      tags = {
        Name        = local.name
        Environment = global.environment
        Project     = "tfstate"
        Owner       = "devops"
      }
    }
  }
}
