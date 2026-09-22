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
| <a name="input_monitor_evaluation_window_min"></a> [monitor\_evaluation\_window\_min](#input\_monitor\_evaluation\_window\_min) | Pod restart 감지 윈도우 (분) | `number` | `5` | no |
| <a name="input_monitor_priority"></a> [monitor\_priority](#input\_monitor\_priority) | Datadog monitor priority (1=highest, 5=lowest). pod restart 노이즈 가능성 고려해 기본 3 | `number` | `3` | no |
| <a name="input_monitor_restart_threshold"></a> [monitor\_restart\_threshold](#input\_monitor\_restart\_threshold) | 해당 윈도우 내 restart 증가량이 이 값을 초과하면 alert (0 = 한 번이라도 restart 시 alert) | `number` | `0` | no |
| <a name="input_notification_tags"></a> [notification\_tags](#input\_notification\_tags) | Datadog monitor 에 추가로 붙일 태그 | `list(string)` | `[]` | no |
| <a name="input_slack_account_name"></a> [slack\_account\_name](#input\_slack\_account\_name) | Datadog Slack integration account name. 공란("") 이면 `@slack-<channel>` 형태 사용 (workspace 단일인 경우 권장). Datadog 에 여러 workspace 등록 시에만 설정. | `string` | `""` | no |
| <a name="input_slack_channel_name"></a> [slack\_channel\_name](#input\_slack\_channel\_name) | Slack channel (leading #), 예: #alert-prd | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_pod_restart_monitor_id"></a> [pod\_restart\_monitor\_id](#output\_pod\_restart\_monitor\_id) | Datadog monitor ID for pod restart alert |
| <a name="output_pod_restart_monitor_url"></a> [pod\_restart\_monitor\_url](#output\_pod\_restart\_monitor\_url) | Datadog monitor URL for pod restart alert |
| <a name="output_slack_channel_name"></a> [slack\_channel\_name](#output\_slack\_channel\_name) | Slack channel that Datadog monitor notifies |

## Resources

| Name | Type |
|------|------|
| [datadog_integration_slack_channel.alert](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/integration_slack_channel) | resource |
| [datadog_monitor.pod_restart](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/monitor) | resource |
<!-- END_TF_DOCS -->