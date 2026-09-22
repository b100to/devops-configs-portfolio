// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "kubernetes_version" {
  default     = "1.35"
  description = "Kubernetes version for the EKS cluster"
  type        = string
}
variable "module_version" {
  default     = "~> 21.9.0"
  description = "Version of the module. (informational — actual pin in main.tm.hcl)"
  type        = string
}
variable "endpoint_public_access_cidrs" {
  default = [
    "0.0.0.0/0",
  ]
  description = "List of CIDR blocks for public access to the cluster endpoint."
  type        = list(string)
}
variable "cluster_admins" {
  default     = {}
  description = "Map of cluster admin users (IAM-user 직접 연결은 레거시. 신규는 Authentik OIDC role 경유)"
  type = map(object({
    email  = string
    scope  = string
    groups = optional(list(string))
  }))
}
variable "security_group_rules" {
  default = {
    istio_http = {
      description = "Node to node ingress on HTTP port"
      from_port   = 80
      protocol    = "tcp"
      self        = true
      to_port     = 80
      type        = "ingress"
    }
  }
  description = "Map of security group rules"
  type = map(object({
    description                   = string
    protocol                      = string
    from_port                     = number
    to_port                       = number
    type                          = string
    self                          = optional(bool)
    source_cluster_security_group = optional(bool)
  }))
}
variable "coredns_replica_count" {
  default     = 1
  description = "Number of replicas for CoreDNS"
  type        = number
}
variable "cloudwatch_log_group_retention_in_days" {
  default     = 5
  description = "Number of days to retain log events in CloudWatch log group"
  type        = number
}
variable "enabled_log_types" {
  default = [
  ]
  description = "List of control plane log types to enable (api, audit, authenticator, controllerManager, scheduler)"
  type        = list(string)
}
