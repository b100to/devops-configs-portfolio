# base-b NodePool: ap-northeast-2c, expireAfter 1080h (45일)
# base(2a, 720h)와 AZ + 만료 주기 분리 → 동시 만료 방지

resource "kubernetes_manifest" "node_pool_b" {
  depends_on = [
    kubernetes_manifest.node_class,
  ]

  manifest = yamldecode(templatefile("${path.module}/nodepool.yaml.tmpl", {
    name              = "base-b"
    node_group        = "base"
    instance_type     = local.instance_type
    instance_types    = local.instance_types
    cpu_limit         = "8"
    memory_limit      = local.memory_limit
    expire_after      = "1080h"
    availability_zone = "ap-northeast-2c"
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
