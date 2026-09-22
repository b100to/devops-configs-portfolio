> **[ARCHIVED 2026-03-10]** 해결 여부 불명. 2025-01-27 이후 VPC 운영 이상 없어 해결된 것으로 추정.

---

# VPC State Drift 수정 필요

**날짜**: 2025-01-27
**스택**: `prd:vpc` (`/stacks/acme/vpc/main/prd`)

## 문제

`module.vpc.aws_route_table_association.private[0]`의 state와 AWS 실제 리소스 ID가 다름

| 구분 | Association ID |
|-----|----------------|
| **State** | `rtbassoc-00000000000000002` |
| **AWS** | `rtbassoc-00000000000000001` |

- Subnet: `subnet-0000000000000001`
- Route Table: `rtb-00000000000000001`

## 해결 방법

```bash
cd /Users/user/works/devops-configs/stacks/acme/vpc/main/prd

# 1. 기존 state에서 제거
terraform state rm 'module.vpc.aws_route_table_association.private[0]'

# 2. 현재 AWS 리소스로 import
terraform import 'module.vpc.aws_route_table_association.private[0]' 'subnet-0000000000000001/rtb-00000000000000001'

# 3. plan으로 확인
terraform plan
```

## 추가 확인 필요

- Plan에서 old cluster tag 제거 (`prd-acme-main`) - blue-green 마이그레이션 정리로 보임
- 다른 route table association도 drift 있는지 확인
