// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

module "eks" {
  access_entries                           = local.access_entries
  addons                                   = local.addons
  cloudwatch_log_group_retention_in_days   = var.cloudwatch_log_group_retention_in_days
  control_plane_subnet_ids                 = local.control_plane_subnet_ids
  enable_cluster_creator_admin_permissions = local.enable_cluster_creator_admin_permissions
  enabled_log_types                        = var.enabled_log_types
  endpoint_public_access                   = local.endpoint_public_access
  endpoint_public_access_cidrs             = var.endpoint_public_access_cidrs
  fargate_profiles                         = local.fargate_profiles_config
  kubernetes_version                       = var.kubernetes_version
  name                                     = local.name
  node_security_group_additional_rules     = var.security_group_rules
  node_security_group_tags                 = local.node_security_group_tags
  security_group_additional_rules = {
    hybrid-all = {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      protocol    = "all"
      to_port     = 0
      type        = "ingress"
    }
  }
  security_group_tags = local.security_group_tags
  source              = "terraform-aws-modules/eks/aws"
  subnet_ids          = local.subnet_ids
  tags                = local.common_tags
  version             = "~> 21.9.0"
  vpc_id              = local.vpc_id
}
