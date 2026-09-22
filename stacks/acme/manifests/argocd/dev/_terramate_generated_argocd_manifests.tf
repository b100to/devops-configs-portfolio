// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "kubernetes_manifest" "root_application_v2" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      annotations = {
        "argocd.argoproj.io/compare-result" = "ignore"
        "argocd.argoproj.io/sync-options"   = "PruneLast=true"
        "argocd.argoproj.io/tracking-id"    = "root-app-v2"
      }
      name      = "root-app-v2"
      namespace = "argocd"
    }
    spec = {
      destination = {
        namespace = "argocd"
        server    = "https://kubernetes.default.svc"
      }
      project = "default"
      source = {
        directory = {
          recurse = true
        }
        path           = "argocd/dev"
        repoURL        = "https://github.com/AcmeCorp/devops-configs.git"
        targetRevision = "main"
      }
      syncPolicy = {
        automated = {
          allowEmpty = false
          prune      = true
          selfHeal   = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "PrunePropagationPolicy=foreground",
          "PruneLast=true",
          "ApplyOutOfSyncOnly=true",
          "Replace=false",
        ]
      }
    }
  }
}
