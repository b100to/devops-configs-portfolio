generate_hcl "_terramate_generated_main.tf" {
  content {
    data "aws_availability_zones" "available" {}

    resource "aws_eip" "nat" {
      count = var.nat_count
      tags = merge(
        local.common_tags,
        {
          "Name" = format("%s-ap-northeast-2%s", var.name, element(["a", "c"], count.index))
        }
      )
    }

    module "vpc" {
      source  = "terraform-aws-modules/vpc/aws"
      version = "6.5.1"

      # 기본 설정
      name = var.name
      cidr = var.vpc_cidr

      # 서브넷 설정
      azs             = local.azs
      public_subnets  = var.public_subnets
      private_subnets = var.private_subnets
      intra_subnets   = var.intra_subnets
      # database_subnets    = local.database_subnets
      # elasticache_subnets = local.elasticache_subnets

      # Public IP 매핑 설정
      map_public_ip_on_launch = var.map_public_ip_on_launch

      # NAT 게이트웨이 설정
      enable_nat_gateway     = var.enable_nat_gateway
      single_nat_gateway     = var.single_nat_gateway
      one_nat_gateway_per_az = var.one_nat_gateway_per_az
      reuse_nat_ips          = var.reuse_nat_ips
      external_nat_ip_ids    = aws_eip.nat.*.id

      # 서브넷 태그 설정
      public_subnet_tags = {
        "kubernetes.io/role/elb"                     = 1
        "kubernetes.io/cluster/${local.eks_name}"    = "shared"
        "kubernetes.io/cluster/${local.eks_name_v2}" = "shared"
      }

      private_subnet_tags = {
        "kubernetes.io/role/internal-elb" = 1
        "karpenter.sh/discovery"          = "true"

        "kubernetes.io/cluster/${local.eks_name}"    = "shared"
        "kubernetes.io/cluster/${local.eks_name_v2}" = "shared"
      }

      # 리소스 태그 설정
      tags = local.common_tags

      # 기본 리소스 관리 비활성화
      manage_default_network_acl    = local.manage_default_network_acl
      manage_default_route_table    = local.manage_default_route_table
      manage_default_security_group = local.manage_default_security_group
      create_database_subnet_group  = local.create_database_subnet_group

      depends_on = [
        aws_eip.nat
      ]
    }
  }
}
