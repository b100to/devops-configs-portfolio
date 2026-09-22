

generate_hcl "_terramate_generated_main.tf" {
  content {
    resource "helm_release" "this" {
      name = local.name

      chart = "${path.module}/.helm/${local.chart}-${local.version}.tgz"

      namespace        = local.namespace
      create_namespace = local.create_namespace

      wait    = local.wait
      timeout = local.timeout

      values = [file("${path.module}/values.yaml")]
    }
  }
}