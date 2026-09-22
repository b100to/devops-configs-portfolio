stack {
  name = "acme_eks_main_v2_prd"
  id   = "acme_eks_main_v2_prd"
  tags = ["stack", "acme", "eks", "main", "v2", "prd"]

  after = [
    "tag:prd:vpc"
  ]
}

input "vpc_id" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_prd"
  value         = outputs.vpc_id.value
  mock          = "MOCK"
}

input "public_subnet_ids" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_prd"
  value         = outputs.public_subnet_ids.value
  mock          = "MOCK"
}


input "private_subnet_ids" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_prd"
  value         = outputs.private_subnet_ids.value
  mock          = "MOCK"
}

input "intra_subnet_ids" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_prd"
  value         = outputs.intra_subnet_ids.value
  mock          = "MOCK"
}
