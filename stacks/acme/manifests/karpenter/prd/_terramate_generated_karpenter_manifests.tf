// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  ami_family      = "AL2023"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  instance_type   = "r7i.2xlarge"
  instance_types = [
  ]
  memory_limit = "64Gi"
}
resource "kubernetes_manifest" "node_class" {
  manifest = yamldecode(templatefile("${path.module}/nodeclass.yaml.tmpl", {
    name             = "base"
    ami_family       = local.ami_family
    karpenter_role   = var.node_iam_role_arn
    subnet_discovery = "true"
    sg_discovery     = local.cluster_name
    name_tag         = "${local.cluster_name}-base"
    environment      = "prd"
    k8s_version      = local.cluster_version
    ignore_fields = [
      "metadata.resourceVersion",
    ]
  }))
  field_manager {
    force_conflicts = true
  }
}
resource "null_resource" "remove_nodeclass_finalizer" {
  triggers = {
    nodeclass_name = "base"
  }
  provisioner "local-exec" {
    command = "kubectl patch ec2nodeclass base --type=json -p='[{\"op\": \"remove\", \"path\": \"/metadata/finalizers\"}]' || true"
    when    = destroy
  }
}
resource "kubernetes_manifest" "node_pool_a" {
  depends_on = [
    kubernetes_manifest.node_class,
  ]
  manifest = yamldecode(templatefile("${path.module}/nodepool.yaml.tmpl", {
    name              = "base"
    node_group        = "base"
    instance_type     = local.instance_type
    instance_types    = local.instance_types
    cpu_limit         = "8"
    memory_limit      = local.memory_limit
    expire_after      = "720h"
    availability_zone = "ap-northeast-2a"
    discovery_tag     = local.cluster_name
    environment       = "prd"
    apply_only        = true
    validate_schema   = false
    force_conflicts   = true
    server_side_apply = true
  }))
  field_manager {
    force_conflicts = true
  }
}
