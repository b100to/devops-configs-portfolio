# Overflow NodePool - DISABLED (2026-03-11)
# t3.2xlarge(8 vCPU) 단일 노드로 전체 워크로드 수용 가능
# 필요 시 아래 resource 블록 주석 해제하여 사용
#
# resource "kubernetes_manifest" "node_pool_overflow" {
#   depends_on = [
#     kubernetes_manifest.node_class,
#   ]
#
#   manifest = yamldecode(templatefile("${path.module}/nodepool-overflow.yaml.tmpl", {
#     name           = "base-overflow"
#     node_group     = "base"
#     nodeclass_name = "base"
#   }))
#
#   field_manager {
#     force_conflicts = true
#   }
# }
