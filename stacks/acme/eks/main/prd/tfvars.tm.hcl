generate_hcl "_terramate_generated_.auto.tfvars" {
  content {
    kubernetes_version = "1.35"
    security_group_rules = {
      istio_http = {
        description = "Node to node ingress on HTTP port"
        from_port   = 80
        protocol    = "tcp"
        self        = true
        to_port     = 80
        type        = "ingress"
      }
      datadog_admission_webhook = {
        description                   = "Cluster API to node 8000/tcp webhook (Datadog)"
        protocol                      = "tcp"
        from_port                     = 8000
        to_port                       = 8000
        type                          = "ingress"
        source_cluster_security_group = true
      }
    }
    coredns_replica_count = 2
  }
}