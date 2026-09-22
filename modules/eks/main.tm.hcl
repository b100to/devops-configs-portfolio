generate_hcl "_terramate_generated_main.tf" {
  content {
    module "eks" {
      source  = "terraform-aws-modules/eks/aws"
      version = "~> 21.9.0"

      # Cluster configuration
      name                     = local.name
      kubernetes_version       = var.kubernetes_version
      vpc_id                   = local.vpc_id
      subnet_ids               = local.subnet_ids
      control_plane_subnet_ids = local.control_plane_subnet_ids

      # Access configuration
      endpoint_public_access_cidrs             = var.endpoint_public_access_cidrs
      endpoint_public_access                   = local.endpoint_public_access
      enable_cluster_creator_admin_permissions = local.enable_cluster_creator_admin_permissions
      security_group_tags                      = local.security_group_tags
      access_entries                           = local.access_entries

      security_group_additional_rules = {
        hybrid-all = {
          cidr_blocks = ["0.0.0.0/0"]
          description = "Allow all traffic from remote node/pod network"
          from_port   = 0
          to_port     = 0
          protocol    = "all"
          type        = "ingress"
        }
      }

      # CoreDNS addon configuration
      addons = local.addons

      # Fargate profiles configuration
      fargate_profiles = local.fargate_profiles_config

      # Security Group rules
      node_security_group_additional_rules = var.security_group_rules
      node_security_group_tags             = local.node_security_group_tags

      # CloudWatch log group
      cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days

      # Control plane logging
      enabled_log_types = var.enabled_log_types

      tags = local.common_tags
    }

  }
}

