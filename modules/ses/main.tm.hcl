generate_hcl "_terramate_generated_main.tf" {
  content {
    # ==========================================================================
    # SES Domain Identity & DKIM
    # ==========================================================================

    resource "aws_ses_domain_identity" "main" {
      domain = var.domain
    }

    resource "aws_ses_domain_dkim" "main" {
      domain = aws_ses_domain_identity.main.domain
    }

    # DKIM CNAME records → Route53
    resource "aws_route53_record" "dkim" {
      count   = 3
      zone_id = var.route53_zone_id
      name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey"
      type    = "CNAME"
      ttl     = 600
      records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
    }

    # Domain verification TXT record → Route53
    resource "aws_route53_record" "verification" {
      zone_id = var.route53_zone_id
      name    = "_amazonses.${var.domain}"
      type    = "TXT"
      ttl     = 600
      records = [aws_ses_domain_identity.main.verification_token]
    }

    # SES domain identity verification (DNS 레코드 추가 후 자동 완료)
    resource "aws_ses_domain_identity_verification" "main" {
      domain = aws_ses_domain_identity.main.id

      depends_on = [aws_route53_record.verification]
    }

    # ==========================================================================
    # IAM User for SMTP
    # ==========================================================================

    resource "aws_iam_user" "smtp" {
      name = local.smtp_user_name
      tags = {
        Environment = var.environment
        Purpose     = "SES SMTP for Plane"
      }
    }

    resource "aws_iam_user_policy" "smtp" {
      name = "ses-send-email"
      user = aws_iam_user.smtp.name

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["ses:SendRawEmail", "ses:SendEmail"]
            Resource = "*"
          }
        ]
      })
    }

    resource "aws_iam_access_key" "smtp" {
      user = aws_iam_user.smtp.name
    }

    # ==========================================================================
    # Secrets Manager - SMTP 자격증명 저장
    # ==========================================================================

    resource "aws_secretsmanager_secret" "smtp" {
      name                    = local.secret_name
      description             = "SES SMTP credentials for ${var.domain} (${var.environment})"
      recovery_window_in_days = 0 # 즉시 삭제 허용 (dev 환경)

      tags = {
        Environment = var.environment
      }
    }

    resource "aws_secretsmanager_secret_version" "smtp" {
      secret_id = aws_secretsmanager_secret.smtp.id
      secret_string = jsonencode({
        smtp_host     = local.smtp_host
        smtp_port     = local.smtp_port
        smtp_username = aws_iam_access_key.smtp.id
        smtp_password = aws_iam_access_key.smtp.ses_smtp_password_v4
        from_email    = var.smtp_from_email
      })
    }
  }
}
