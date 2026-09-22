// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "helm_release" "this" {
  chart            = "${path.module}/.helm/${local.chart}-${local.version}.tgz"
  create_namespace = local.create_namespace
  name             = local.name
  namespace        = local.namespace
  timeout          = local.timeout
  values = [
    file("${path.module}/values.yaml"),
  ]
  wait = local.wait
}
