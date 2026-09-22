// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_ses_domain_identity" "main" {
  domain = var.domain
}
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}
resource "aws_route53_record" "dkim" {
  count = 3
  name  = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey"
  records = [
    "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com",
  ]
  ttl     = 600
  type    = "CNAME"
  zone_id = var.route53_zone_id
}
resource "aws_route53_record" "verification" {
  name = "_amazonses.${var.domain}"
  records = [
    aws_ses_domain_identity.main.verification_token,
  ]
  ttl     = 600
  type    = "TXT"
  zone_id = var.route53_zone_id
}
resource "aws_ses_domain_identity_verification" "main" {
  depends_on = [
    aws_route53_record.verification,
  ]
  domain = aws_ses_domain_identity.main.id
}
resource "aws_iam_user" "smtp" {
  name = local.smtp_user_name
  tags = {
    Environment = var.environment
    Purpose     = "SES SMTP for Plane"
  }
}
resource "aws_iam_user_policy" "smtp" {
  name = "ses-send-email"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendRawEmail",
          "ses:SendEmail",
        ]
        Resource = "*"
      },
    ]
  })
  user = aws_iam_user.smtp.name
}
resource "aws_iam_access_key" "smtp" {
  user = aws_iam_user.smtp.name
}
resource "aws_secretsmanager_secret" "smtp" {
  description             = "SES SMTP credentials for ${var.domain} (${var.environment})"
  name                    = local.secret_name
  recovery_window_in_days = 0
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
