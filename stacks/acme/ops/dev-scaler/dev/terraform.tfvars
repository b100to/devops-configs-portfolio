environment = "dev"
account_id  = "111111111111"

cluster_name  = "acme-main-v2-dev"
slack_channel = "C0000000002" # #alert-dev-scaler

# base: t3.2xlarge (cpu:8), overflow 비활성화
nodepools_config = "[{\"name\":\"base\",\"limits\":{\"cpu\":\"8\"}}]"
