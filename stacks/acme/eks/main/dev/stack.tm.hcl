stack {
  name = "acme_eks_main_v2_dev"
  id   = "acme_eks_main_v2_dev"
  tags = ["stack", "acme", "eks", "v2", "dev"]

  after = [
    "tag:dev:vpc"
  ]
}

input "vpc_id" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_dev"
  value         = outputs.vpc_id.value
  mock          = "MOCK"
}

input "public_subnet_ids" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_dev"
  value         = outputs.public_subnet_ids.value
  mock          = "MOCK"
}


input "private_subnet_ids" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_dev"
  value         = outputs.private_subnet_ids.value
  mock          = "MOCK"
}

input "intra_subnet_ids" {
  backend       = "default"
  from_stack_id = "acme_vpc_main_dev"
  value         = outputs.intra_subnet_ids.value
  mock          = "MOCK"
}