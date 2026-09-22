// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  azs = [
    data.aws_availability_zones.available.names[0],
    data.aws_availability_zones.available.names[2],
  ]
  common_tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
  create_database_subnet_group  = false
  database_subnets              = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 130)]
  eks_name                      = "acme-main-prd"
  eks_name_v2                   = "acme-main-v2-prd"
  elasticache_subnets           = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 133)]
  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false
}
