# =============================================================================
# Outline - Secrets Manager 설정
# - SECRET_KEY, UTILS_SECRET, DB password: Terraform이 자동 생성하여 outline/prd 키에 저장
# - OIDC_CLIENT_SECRET: eks/acme-main-v2-prd:outline_oidc_client_secret 에서 참조 (수동 관리)
# - Authentik OIDC 설정: manifests/authentik/prd/blueprints.yaml (Blueprint 방식)
# - DB 유저/DB 생성: manifests/outline/prd/db-init-job.yaml (K8s Job)
# =============================================================================

locals {
  rds_host = "airflow.cluster-abcdefghijkl.ap-northeast-2.rds.amazonaws.com"
}

# --- Random 값 생성 ---

resource "random_bytes" "secret_key" {
  length = 32
}

resource "random_bytes" "utils_secret" {
  length = 32
}

resource "random_password" "db_password" {
  length  = 32
  special = false # psql URL 특수문자 인코딩 이슈 방지
}

# --- Secrets Manager ---

resource "aws_secretsmanager_secret" "outline" {
  name        = "outline/prd"
  description = "Outline wiki (wiki.acme.example) 운영 시크릿"

  tags = {
    Service     = "outline"
    Environment = "prd"
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "outline" {
  secret_id = aws_secretsmanager_secret.outline.id

  secret_string = jsonencode({
    SECRET_KEY   = random_bytes.secret_key.hex
    UTILS_SECRET = random_bytes.utils_secret.hex
    DATABASE_URL = "postgres://outline:${random_password.db_password.result}@${local.rds_host}:5432/outline"
    DB_PASSWORD  = random_password.db_password.result
  })
}
