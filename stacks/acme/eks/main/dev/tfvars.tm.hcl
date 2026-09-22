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
    }
  }
}