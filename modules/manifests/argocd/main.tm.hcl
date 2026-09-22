generate_hcl "_terramate_generated_argocd_manifests.tf" {
  content {
    # resource "kubernetes_manifest" "root_application" {
    #   manifest = {
    #     apiVersion = "argoproj.io/v1alpha1"
    #     kind       = "Application"
    #     metadata = {
    #       name      = "root-app"
    #       namespace = "argocd"
    #       annotations = {
    #         "argocd.argoproj.io/sync-options" = "PruneLast=true"
    #         "argocd.argoproj.io/refresh"      = "10"
    #       }
    #     }
    #     spec = {
    #       destination = {
    #         namespace = "argocd"
    #         server    = "https://kubernetes.default.svc"
    #       }
    #       project = "default"
    #       source = {
    #         path           = "argocd/${global.environment}"
    #         repoURL        = "https://github.com/AcmeCorp/devops-configs.git"
    #         targetRevision = "main"
    #         directory = {
    #           recurse = true
    #         }
    #       }
    #       syncPolicy = {
    #         automated = {
    #           prune      = true
    #           selfHeal   = true
    #           allowEmpty = false
    #         }
    #         syncOptions = [
    #           "CreateNamespace=true",
    #           "PrunePropagationPolicy=foreground",
    #           "PruneLast=true",
    #           "ApplyOutOfSyncOnly=true",
    #           "Replace=false",
    #         ]
    #       }
    #     }
    #   }
    # }

    resource "kubernetes_manifest" "root_application_v2" {
      manifest = {
        apiVersion = "argoproj.io/v1alpha1"
        kind       = "Application"
        metadata = {
          name      = "root-app-v2"
          namespace = "argocd"
          annotations = {
            "argocd.argoproj.io/sync-options"   = "PruneLast=true" # 삭제할 리소스를 마지막에 처리하여 의존성 문제 방지
            "argocd.argoproj.io/compare-result" = "ignore"         # 비교 결과 차이 무시
            "argocd.argoproj.io/tracking-id"    = "root-app-v2"    # Application 식별자로 리소스 소유권 추적
          }
        }
        spec = {
          destination = {
            namespace = "argocd"
            server    = "https://kubernetes.default.svc"
          }
          project = "default"
          source = {
            path           = "argocd/${global.environment}"
            repoURL        = "https://github.com/AcmeCorp/devops-configs.git"
            targetRevision = "main"
            directory = {
              recurse = true
            }
          }
          syncPolicy = {
            automated = {
              prune      = true
              selfHeal   = true
              allowEmpty = false
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

  }
}