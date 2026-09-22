<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_domain"></a> [domain](#input\_domain) | SES domain to verify (e.g. dev.acme.example) | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev/prd) | `string` | n/a | yes |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 hosted zone ID for the domain | `string` | n/a | yes |
| <a name="input_secret_name"></a> [secret\_name](#input\_secret\_name) | Secrets Manager secret name for SMTP credentials | `string` | `""` | no |
| <a name="input_smtp_from_email"></a> [smtp\_from\_email](#input\_smtp\_from\_email) | Default FROM email address (e.g. no-reply@dev.acme.example) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_secret_name"></a> [secret\_name](#output\_secret\_name) | Secrets Manager secret name for SMTP credentials |
| <a name="output_ses_domain"></a> [ses\_domain](#output\_ses\_domain) | SES verified domain |
| <a name="output_smtp_host"></a> [smtp\_host](#output\_smtp\_host) | SES SMTP host |
| <a name="output_smtp_password"></a> [smtp\_password](#output\_smtp\_password) | SMTP password (SES SigV4) |
| <a name="output_smtp_port"></a> [smtp\_port](#output\_smtp\_port) | SES SMTP port (TLS) |
| <a name="output_smtp_username"></a> [smtp\_username](#output\_smtp\_username) | SMTP username (IAM Access Key ID) |

## Resources

| Name | Type |
|------|------|
| [aws_iam_access_key.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_user.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_policy.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy) | resource |
| [aws_route53_record.dkim](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.verification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_secretsmanager_secret.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.smtp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_ses_domain_dkim.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_domain_dkim) | resource |
| [aws_ses_domain_identity.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_domain_identity) | resource |
| [aws_ses_domain_identity_verification.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ses_domain_identity_verification) | resource |
<!-- END_TF_DOCS -->