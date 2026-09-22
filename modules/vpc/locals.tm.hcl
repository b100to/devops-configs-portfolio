generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      common_tags = global.tags

      azs = [
        data.aws_availability_zones.available.names[0], // a 영역
        data.aws_availability_zones.available.names[2], // c 영역
      ]

      manage_default_network_acl    = false
      manage_default_route_table    = false
      manage_default_security_group = false
      create_database_subnet_group  = false

      database_subnets    = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 130)]
      elasticache_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 133)]

      eks_name    = tm_join("-", [global.domain, "main", global.environment])
      eks_name_v2 = tm_join("-", [global.domain, "main", "v2", global.environment])
    }
  }
}