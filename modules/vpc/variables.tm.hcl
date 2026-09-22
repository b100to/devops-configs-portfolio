generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "name" {
      description = "VPC 이름"
      type        = string
    }

    variable "vpc_cidr" {
      description = "VPC CIDR 블록"
      type        = string
      default     = "10.0.0.0/16"
    }

    variable "nat_count" {
      description = "NAT 게이트웨이 개수"
      type        = number
      default     = 1
    }

    variable "public_subnets" {
      description = "퍼블릭 서브넷 CIDR 블록 목록"
      type        = list(string)
      default = [
        "10.0.0.0/20",
        "10.0.48.0/20",
      ]
    }

    variable "private_subnets" {
      description = "프라이빗 서브넷 CIDR 블록 목록"
      type        = list(string)
      default = [
        "10.0.16.0/20",
        "10.0.64.0/20",
      ]
    }

    variable "intra_subnets" {
      description = "인트라 서브넷 CIDR 블록 목록"
      type        = list(string)
      default = [
        "10.0.144.0/24",
        "10.0.146.0/24",
      ]
    }

    variable "map_public_ip_on_launch" {
      description = "퍼블릭 서브넷에서 시작하는 인스턴스에 퍼블릭 IP 할당 여부"
      type        = bool
      default     = true
    }

    variable "enable_nat_gateway" {
      description = "NAT 게이트웨이 활성화 여부"
      type        = bool
      default     = true
    }

    variable "single_nat_gateway" {
      description = "단일 NAT 게이트웨이 사용 여부"
      type        = bool
      default     = true
    }

    variable "one_nat_gateway_per_az" {
      description = "각 가용 영역당 NAT 게이트웨이 배치 여부"
      type        = bool
      default     = false
    }

    variable "reuse_nat_ips" {
      description = "NAT IP 재사용 여부"
      type        = bool
      default     = true
    }
  }
}
