generate_hcl "_terramate_generated_outputs.tf" {
  content {
    output "ses_domain" {
      description = "SES verified domain"
      value       = aws_ses_domain_identity.main.domain
    }

    output "smtp_host" {
      description = "SES SMTP host"
      value       = local.smtp_host
    }

    output "smtp_port" {
      description = "SES SMTP port (TLS)"
      value       = local.smtp_port
    }

    output "smtp_username" {
      description = "SMTP username (IAM Access Key ID)"
      value       = aws_iam_access_key.smtp.id
    }

    output "smtp_password" {
      description = "SMTP password (SES SigV4)"
      value       = aws_iam_access_key.smtp.ses_smtp_password_v4
      sensitive   = true
    }

    output "secret_name" {
      description = "Secrets Manager secret name for SMTP credentials"
      value       = aws_secretsmanager_secret.smtp.name
    }
  }
}
