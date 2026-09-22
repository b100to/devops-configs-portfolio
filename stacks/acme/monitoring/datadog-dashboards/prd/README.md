<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | 1.13.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.28.0 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~> 3.60.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.28.0 |
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | ~> 3.60.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account ID (for Secrets Manager data source) | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name used as cluster\_name tag in Datadog metrics | `string` | n/a | yes |
| <a name="input_datadog_secret_name"></a> [datadog\_secret\_name](#input\_datadog\_secret\_name) | AWS Secrets Manager secret name that contains DD\_API\_KEY and DD\_APP\_KEY (JSON) | `string` | `"eks/acme-main-v2-prd"` | no |
| <a name="input_datadog_site"></a> [datadog\_site](#input\_datadog\_site) | Datadog site (datadoghq.com / datadoghq.eu / us3.datadoghq.com 등) | `string` | `"datadoghq.com"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev/prd) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dashboard_url"></a> [dashboard\_url](#output\_dashboard\_url) | Datadog Airflow 대시보드 URL |

## Resources

| Name | Type |
|------|------|
| [datadog_dashboard.airflow](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/dashboard) | resource |
<!-- END_TF_DOCS -->