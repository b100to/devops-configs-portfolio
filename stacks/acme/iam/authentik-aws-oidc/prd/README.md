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
| <a name="input_admin_policy_arns"></a> [admin\_policy\_arns](#input\_admin\_policy\_arns) | Managed policy ARNs for admin role | `list(string)` | <pre>[<br/>  "arn:aws:iam::aws:policy/AdministratorAccess"<br/>]</pre> | no |
| <a name="input_admin_role_name"></a> [admin\_role\_name](#input\_admin\_role\_name) | IAM role name for devops-admin group | `string` | `"authentik-oidc-admin"` | no |
| <a name="input_allowed_source_ips"></a> [allowed\_source\_ips](#input\_allowed\_source\_ips) | Allowed source IP CIDRs for AssumeRoleWithWebIdentity (e.g. office IP) | `list(string)` | `[]` | no |
| <a name="input_allowed_sub_pattern"></a> [allowed\_sub\_pattern](#input\_allowed\_sub\_pattern) | Pattern for allowed sub claim (e.g. *@acme-corp.example) | `string` | `"*@acme-corp.example"` | no |
| <a name="input_developer_policy_arns"></a> [developer\_policy\_arns](#input\_developer\_policy\_arns) | Managed policy ARNs for developer role | `list(string)` | n/a | yes |
| <a name="input_developer_role_name"></a> [developer\_role\_name](#input\_developer\_role\_name) | IAM role name for developer group | `string` | `"authentik-oidc-developer"` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration in seconds | `number` | `43200` | no |
| <a name="input_oidc_client_ids"></a> [oidc\_client\_ids](#input\_oidc\_client\_ids) | OIDC client IDs (audience) | `list(string)` | n/a | yes |
| <a name="input_oidc_provider_url"></a> [oidc\_provider\_url](#input\_oidc\_provider\_url) | OIDC provider URL (e.g. https://sso.acme.example/application/o/aws-cli/) | `string` | n/a | yes |
| <a name="input_oidc_thumbprints"></a> [oidc\_thumbprints](#input\_oidc\_thumbprints) | TLS certificate thumbprints for the OIDC provider | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_role_arn"></a> [admin\_role\_arn](#output\_admin\_role\_arn) | ARN of admin IAM role for OIDC login |
| <a name="output_developer_role_arn"></a> [developer\_role\_arn](#output\_developer\_role\_arn) | ARN of developer IAM role for OIDC login |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of AWS IAM OIDC provider |

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.authentik](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.oidc_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.oidc_developer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.oidc_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.oidc_developer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
<!-- END_TF_DOCS -->