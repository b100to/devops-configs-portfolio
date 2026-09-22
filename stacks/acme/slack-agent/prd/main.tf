# =============================================================================
# Slack DevOps Agent - Secrets Manager
# - 껍데기만 Terraform으로 생성, 값은 AWS CLI로 주입
# - 포함 키: slack_bot_token, slack_signing_secret, zai_api_key
# =============================================================================

resource "aws_secretsmanager_secret" "slack_agent" {
  name        = "slack-agent/config"
  description = "Slack DevOps Agent - Bot Token, Signing Secret, z.ai API Key"

  recovery_window_in_days = 7

  tags = {
    Service     = "slack-agent"
    Environment = "prd"
    ManagedBy   = "terraform"
  }
}

# 초기 빈 값 — apply 후 CLI로 실제 값 주입
resource "aws_secretsmanager_secret_version" "slack_agent" {
  secret_id = aws_secretsmanager_secret.slack_agent.id

  secret_string = jsonencode({
    slack_bot_token      = "REPLACE_ME"
    slack_signing_secret = "REPLACE_ME"
    zai_api_key          = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
