<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | 1.13.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.28.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.17.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.19.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.38.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws.virginia"></a> [aws.virginia](#provider\_aws.virginia) | 6.28.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addon_resources"></a> [addon\_resources](#input\_addon\_resources) | 리소스 설정 (CPU/메모리 요청 및 제한) | <pre>map(object({<br/>    cpu_request    = string<br/>    memory_request = string<br/>    cpu_limit      = string<br/>    memory_limit   = string<br/>  }))</pre> | <pre>{<br/>  "kube_proxy": {<br/>    "cpu_limit": "50m",<br/>    "cpu_request": "20m",<br/>    "memory_limit": "50Mi",<br/>    "memory_request": "25Mi"<br/>  },<br/>  "pod_identity": {<br/>    "cpu_limit": "30m",<br/>    "cpu_request": "15m",<br/>    "memory_limit": "40Mi",<br/>    "memory_request": "25Mi"<br/>  },<br/>  "vpc_cni": {<br/>    "cpu_limit": "30m",<br/>    "cpu_request": "15m",<br/>    "memory_limit": "100Mi",<br/>    "memory_request": "70Mi"<br/>  }<br/>}</pre> | no |
| <a name="input_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#input\_cluster\_certificate\_authority\_data) | n/a | `any` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | n/a | `any` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | n/a | `any` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | n/a | `any` | n/a | yes |
| <a name="input_eks_addons"></a> [eks\_addons](#input\_eks\_addons) | Map of EKS add-ons to be installed. | `map(any)` | <pre>{<br/>  "eks-pod-identity-agent": {},<br/>  "kube-proxy": {},<br/>  "vpc-cni": {}<br/>}</pre> | no |
| <a name="input_enable_aws_efs_csi_driver"></a> [enable\_aws\_efs\_csi\_driver](#input\_enable\_aws\_efs\_csi\_driver) | EFS CSI Driver 설치 여부 (Helm + IRSA 자동 생성) | `bool` | `false` | no |
| <a name="input_enable_prefix_delegation"></a> [enable\_prefix\_delegation](#input\_enable\_prefix\_delegation) | VPC CNI prefix delegation 활성화 여부 (노드당 IP 용량 증가) | `bool` | `false` | no |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | n/a | `any` | n/a | yes |

## Outputs

No outputs.

## Resources

| Name | Type |
|------|------|
<!-- END_TF_DOCS -->