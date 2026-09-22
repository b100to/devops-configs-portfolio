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

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_airflow_connection_bundle_secret_arns"></a> [airflow\_connection\_bundle\_secret\_arns](#output\_airflow\_connection\_bundle\_secret\_arns) | Airflow connection bundle Secrets Manager ARNs |
| <a name="output_airflow_connection_bundle_secret_names"></a> [airflow\_connection\_bundle\_secret\_names](#output\_airflow\_connection\_bundle\_secret\_names) | Airflow connection bundle Secrets Manager names |

## Resources

| Name | Type |
|------|------|
| [aws_secretsmanager_secret.airflow_connection_bundle](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
<!-- END_TF_DOCS -->