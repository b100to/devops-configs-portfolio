// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "name" {
  description = "VPC 이름"
  type        = string
}
variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "VPC CIDR 블록"
  type        = string
}
variable "nat_count" {
  default     = 1
  description = "NAT 게이트웨이 개수"
  type        = number
}
variable "public_subnets" {
  default = [
    "10.0.0.0/20",
    "10.0.48.0/20",
  ]
  description = "퍼블릭 서브넷 CIDR 블록 목록"
  type        = list(string)
}
variable "private_subnets" {
  default = [
    "10.0.16.0/20",
    "10.0.64.0/20",
  ]
  description = "프라이빗 서브넷 CIDR 블록 목록"
  type        = list(string)
}
variable "intra_subnets" {
  default = [
    "10.0.144.0/24",
    "10.0.146.0/24",
  ]
  description = "인트라 서브넷 CIDR 블록 목록"
  type        = list(string)
}
variable "map_public_ip_on_launch" {
  default     = true
  description = "퍼블릭 서브넷에서 시작하는 인스턴스에 퍼블릭 IP 할당 여부"
  type        = bool
}
variable "enable_nat_gateway" {
  default     = true
  description = "NAT 게이트웨이 활성화 여부"
  type        = bool
}
variable "single_nat_gateway" {
  default     = true
  description = "단일 NAT 게이트웨이 사용 여부"
  type        = bool
}
variable "one_nat_gateway_per_az" {
  default     = false
  description = "각 가용 영역당 NAT 게이트웨이 배치 여부"
  type        = bool
}
variable "reuse_nat_ips" {
  default     = true
  description = "NAT IP 재사용 여부"
  type        = bool
}
