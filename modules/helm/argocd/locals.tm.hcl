generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      name       = "argocd"
      repository = "https://argoproj.github.io/argo-helm"
      chart      = "argo-cd"
      version    = "9.0.6"

      namespace        = "argocd"
      create_namespace = true
      wait             = true
      timeout          = 150
    }

  }
}