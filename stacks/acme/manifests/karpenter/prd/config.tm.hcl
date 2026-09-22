globals {
  environment   = "prd"
  account_id    = "222222222222"
  instance_type = "r7i.2xlarge" # (미사용)
  cpu_limit     = "8"           # r7i.2xlarge 1대 (8 vCPU) = AZ당 최대 1노드
}