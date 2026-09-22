generate_hcl "_terramate_generated_external_secrets_manifests.tf" {
  content {
    locals {
      cluster_name = var.cluster_name
      secrets_key  = "eks/${tm_element(tm_split("/", terramate.stack.path.absolute), tm_length(tm_split("/", terramate.stack.path.absolute)) - 1)}"
    }

    # ArgoCD namespace 확인 (이미 존재하면 사용, 없으면 생성)
    resource "kubernetes_namespace" "argocd" {
      count = length(try(data.kubernetes_namespace.argocd_existing.id, "")) > 0 ? 0 : 1
      metadata {
        name = "argocd"
      }
    }

    data "kubernetes_namespace" "argocd_existing" {
      metadata {
        name = "argocd"
      }
    }

    resource "kubectl_manifest" "cluster_secret_store" {
      yaml_body = <<-YAML
        apiVersion: external-secrets.io/v1
        kind: ClusterSecretStore
        metadata:
          name: aws-secrets-store
        spec:
          provider:
            aws:
              service: SecretsManager
              region: ap-northeast-2
      YAML
    }

    resource "kubectl_manifest" "argocd_webhook_secret" {
      yaml_body = <<-YAML
        apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata:
          name: argocd-webhook-secret
          namespace: argocd
        spec:
          refreshInterval: 15m
          secretStoreRef:
            name: aws-secrets-store
            kind: ClusterSecretStore
          target:
            name: argocd-webhook-secret
            creationPolicy: Owner
            template:
              metadata:
                labels:
                  app.kubernetes.io/part-of: argocd
          data:
            - secretKey: webhook.github.secret
              remoteRef:
                key: eks/acme-main-v2-${global.environment}
                property: webhook_github_secret
            - secretKey: oidc.authentik.clientSecret
              remoteRef:
                key: eks/acme-main-v2-${global.environment}
                property: argocd_oidc_authentik_client_secret
      YAML

      depends_on = [
        kubectl_manifest.cluster_secret_store,
      ]
    }

    resource "kubectl_manifest" "argocd_repo_creds" {
      yaml_body = <<-YAML
        apiVersion: external-secrets.io/v1
        kind: ExternalSecret
        metadata:
          name: argocd-repo-creds
          namespace: argocd
        spec:
          refreshInterval: 15m
          secretStoreRef:
            name: aws-secrets-store
            kind: ClusterSecretStore
          target:
            name: argocd-repo-creds
            creationPolicy: Owner
            template:
              metadata:
                labels:
                  argocd.argoproj.io/secret-type: repo-creds
              data:
                type: git
                url: https://github.com/AcmeCorp
                username: fietpet-dev-git
                password: "{{ .github_pat }}"
          data:
            - secretKey: github_pat
              remoteRef:
                key: eks/acme-main-v2-${global.environment}
                property: github_pat
      YAML

      depends_on = [
        kubectl_manifest.cluster_secret_store,
      ]
    }
  }
}
