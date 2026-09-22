<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | 1.13.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.28.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.28.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_instance_profile_name"></a> [instance\_profile\_name](#input\_instance\_profile\_name) | IAM instance profile name attached to the blog EC2 | `string` | `"blog-ssm-profile"` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | IAM role name for the SSM-managed blog bastion | `string` | `"blog-ssm-role"` | no |
| <a name="input_session_log_group_name"></a> [session\_log\_group\_name](#input\_session\_log\_group\_name) | CloudWatch log group name for SSM Session Manager session logs (audit) | `string` | `"/aws/ssm/session-logs/prd"` | no |
| <a name="input_session_log_retention_days"></a> [session\_log\_retention\_days](#input\_session\_log\_retention\_days) | Retention period (days) for session logs — ISMS 로그 보존기간 | `number` | `365` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_profile_arn"></a> [instance\_profile\_arn](#output\_instance\_profile\_arn) | 인스턴스 프로파일 ARN |
| <a name="output_instance_profile_name"></a> [instance\_profile\_name](#output\_instance\_profile\_name) | blog EC2에 연결할 인스턴스 프로파일 이름 |
| <a name="output_session_log_group_name"></a> [session\_log\_group\_name](#output\_session\_log\_group\_name) | 세션 문서 cloudWatchLogGroupName에 설정할 로그그룹 이름 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.ssm_sessions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_instance_profile.blog_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.blog_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.session_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ssm_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
<!-- END_TF_DOCS -->