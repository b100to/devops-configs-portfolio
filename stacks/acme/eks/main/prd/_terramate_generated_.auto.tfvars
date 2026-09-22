// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

coredns_replica_count = 2
kubernetes_version    = "1.35"
security_group_rules = {
  datadog_admission_webhook = {
    description                   = "Cluster API to node 8000/tcp webhook (Datadog)"
    from_port                     = 8000
    protocol                      = "tcp"
    source_cluster_security_group = true
    to_port                       = 8000
    type                          = "ingress"
  }
  istio_http = {
    description = "Node to node ingress on HTTP port"
    from_port   = 80
    protocol    = "tcp"
    self        = true
    to_port     = 80
    type        = "ingress"
  }
}
