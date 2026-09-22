// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "aws_availability_zones" "available" {
}
resource "aws_eip" "nat" {
  count = var.nat_count
  tags = merge(local.common_tags, {
    "Name" = format("%s-ap-northeast-2%s", var.name, element([
      "a",
      "c",
    ], count.index))
  })
}
module "vpc" {
  azs                          = local.azs
  cidr                         = var.vpc_cidr
  create_database_subnet_group = local.create_database_subnet_group
  depends_on = [
    aws_eip.nat,
  ]
  enable_nat_gateway            = var.enable_nat_gateway
  external_nat_ip_ids           = aws_eip.nat[*].id
  intra_subnets                 = var.intra_subnets
  manage_default_network_acl    = local.manage_default_network_acl
  manage_default_route_table    = local.manage_default_route_table
  manage_default_security_group = local.manage_default_security_group
  map_public_ip_on_launch       = var.map_public_ip_on_launch
  name                          = var.name
  one_nat_gateway_per_az        = var.one_nat_gateway_per_az
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = 1
    "karpenter.sh/discovery"                     = "true"
    "kubernetes.io/cluster/${local.eks_name}"    = "shared"
    "kubernetes.io/cluster/${local.eks_name_v2}" = "shared"
  }
  private_subnets = var.private_subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                     = 1
    "kubernetes.io/cluster/${local.eks_name}"    = "shared"
    "kubernetes.io/cluster/${local.eks_name_v2}" = "shared"
  }
  public_subnets     = var.public_subnets
  reuse_nat_ips      = var.reuse_nat_ips
  single_nat_gateway = var.single_nat_gateway
  source             = "terraform-aws-modules/vpc/aws"
  tags               = local.common_tags
  version            = "6.5.1"
}
