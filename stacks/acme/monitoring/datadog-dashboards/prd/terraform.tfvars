environment = "prd"
account_id  = "222222222222"

cluster_name = "acme-main-v2-prd"

# external-secrets 가 사용 중인 시크릿 재사용 (DD_API_KEY, DD_APP_KEY 필드)
datadog_secret_name = "eks/acme-main-v2-prd"
datadog_site        = "datadoghq.com"
