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
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | AWS Account ID | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev/prd) | `string` | n/a | yes |
| <a name="input_finding_publishing_frequency"></a> [finding\_publishing\_frequency](#input\_finding\_publishing\_frequency) | Frequency for publishing GuardDuty findings (FIFTEEN\_MINUTES, ONE\_HOUR, SIX\_HOURS) | `string` | `"FIFTEEN_MINUTES"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_detector_arn"></a> [detector\_arn](#output\_detector\_arn) | GuardDuty detector ARN |
| <a name="output_detector_id"></a> [detector\_id](#output\_detector\_id) | GuardDuty detector ID |

## Resources

| Name | Type |
|------|------|
| [aws_guardduty_detector.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector) | resource |
<!-- END_TF_DOCS -->