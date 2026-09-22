// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  secret_name    = var.secret_name != "" ? var.secret_name : "ses/smtp-credentials-${var.environment}"
  smtp_host      = "email-smtp.ap-northeast-2.amazonaws.com"
  smtp_port      = 587
  smtp_user_name = "acme-ses-smtp-${var.environment}"
}
