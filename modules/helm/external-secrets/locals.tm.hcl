generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      name       = "external-secrets"
      repository = "https://charts.external-secrets.io"
      chart      = "external-secrets"
      version    = "1.1.0"

      namespace        = "external-secrets"
      create_namespace = true
      wait             = true
      timeout          = 150
    }
  }
}
