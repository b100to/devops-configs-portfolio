# 수동 작업 내역

이 문서는 Terraform으로 자동화되지 않은 수동 변경 리소스만 간단히 기록합니다.

---

## EKS Control Plane 보안 그룹 인바운드 규칙 수동 추가 ✅

EKS control plane 보안 그룹에 다음 3개의 인바운드 규칙을 AWS 콘솔에서 수동으로 추가해야 합니다:

### 추가할 규칙

| 유형 | 프로토콜 | 포트 범위 | 소스 | 설명 |
|------|----------|----------|------|------|
| 사용자 지정 UDP | UDP | 53 | 소스 노드 보안 그룹 | DNS (UDP) |
| 사용자 지정 TCP | TCP | 53 | 소스 노드 보안 그룹 | DNS (TCP) |
| HTTPS | TCP | 443 | 소스 노드 보안 그룹 | HTTPS |

### 설정 방법

1. AWS 콘솔에서 EKS 클러스터의 control plane 보안 그룹으로 이동
2. "인바운드 규칙 편집" 클릭
3. 위 3개 규칙 추가:
   - **규칙 1**: UDP 53, 소스 = 노드 보안 그룹
   - **규칙 2**: TCP 53, 소스 = 노드 보안 그룹
   - **규칙 3**: TCP 443, 소스 = 노드 보안 그룹
4. 규칙 저장

> **참고**: 이 규칙들은 EKS 노드가 control plane과 통신할 수 있도록 허용합니다 (DNS 조회 및 API 서버 접근).

---

## 2025-06-25 PRD 환경 보안 그룹 인바운드 규칙 수동 변경 ⚠️ (상세 내역 미기록)

- **acme-main-prd-node** (`sg-0000000000000007`)
- **acme-main-prd-cluster** (`sg-0000000000000001`)
- **eks-cluster-sg-acme-main-prd-0000000000** (`sg-00000000000000041`)

> 위 3개 보안 그룹의 인바운드 규칙을 AWS 콘솔에서 수동으로 추가/수정함 (상세 내역은 추후 정리)

---

## 2025-12-08 Karpenter Controller IAM 권한 추가 ✅

Karpenter Controller가 Instance Profile을 조회할 수 있도록 IAM 권한을 추가해야 합니다.

### 문제
- Karpenter가 `iam:ListInstanceProfiles` 권한이 없어서 Instance Profile을 찾지 못함
- 이로 인해 EC2NodeClass가 Ready 상태가 되지 않음
- Instance Profile 쿼터(1000개)에 도달하는 문제 발생

### 해결 방법

**Karpenter Controller IAM 역할**에 다음 정책 추가:
- 역할 이름: `KarpenterController-<generated-suffix>` (또는 최신 역할)

#### 추가할 IAM 정책 JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "KarpenterInstanceProfilePermissions",
      "Effect": "Allow",
      "Action": [
        "iam:GetInstanceProfile",
        "iam:ListInstanceProfiles"
      ],
      "Resource": "*"
    }
  ]
}
```

### AWS CLI로 추가하는 방법:

```bash
# 1. 정책 JSON 파일 생성
cat > /tmp/karpenter-iam-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "KarpenterInstanceProfilePermissions",
      "Effect": "Allow",
      "Action": [
        "iam:GetInstanceProfile",
        "iam:ListInstanceProfiles"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# 2. IAM 정책 생성
aws iam create-policy \
  --policy-name KarpenterInstanceProfileAccess \
  --policy-document file:///tmp/karpenter-iam-policy.json

# 3. Karpenter Controller 역할에 정책 연결
aws iam attach-role-policy \
  --role-name KarpenterController-<generated-suffix> \
  --policy-arn arn:aws:iam::111111111111:policy/KarpenterInstanceProfileAccess

# 4. Karpenter 재시작 (IAM 권한 반영)
kubectl rollout restart deployment karpenter -n karpenter
```

### AWS 콘솔에서 추가하는 방법:

1. IAM 콘솔 → 역할 → `KarpenterController-*` 역할 선택
2. "권한 추가" → "정책 연결" 클릭
3. "정책 생성" 클릭
4. JSON 탭에서 위 정책 JSON 붙여넣기
5. 정책 이름: `KarpenterInstanceProfileAccess`
6. 정책 생성 후 역할에 연결
7. Karpenter 재시작: `kubectl rollout restart deployment karpenter -n karpenter`

> **참고**: 이 권한은 Karpenter v1 API를 사용할 때 필요하며, Instance Profile을 동적으로 관리하기 위해 필수입니다.

---

## 2026-01-22 PRD v2 환경 보안 그룹 인바운드 규칙 추가 ✅

EKS v2 PRD 클러스터(`acme-main-v2-prd`)의 Control Plane 보안 그룹에 노드 통신 규칙 추가.

### 보안 그룹 정보

| 구분 | Security Group ID | 이름 |
|------|-------------------|------|
| Control Plane | `sg-0000000000000006` | EKS cluster SG |
| Node | `sg-0000000000000008` | acme-main-v2-prd-node-* |

### 추가된 규칙

| 규칙 ID | 프로토콜 | 포트 | 소스 | 설명 |
|---------|----------|------|------|------|
| `sgr-00000000000000001` | UDP | 53 | Node SG | DNS (UDP) |
| `sgr-00000000000000002` | TCP | 53 | Node SG | DNS (TCP) |
| `sgr-00000000000000003` | TCP | 443 | Node SG | HTTPS (API Server) |

### 실행한 명령어

```bash
export AWS_PROFILE=prd

# DNS UDP
aws ec2 authorize-security-group-ingress --group-id sg-0000000000000006 \
  --protocol udp --port 53 --source-group sg-0000000000000008

# DNS TCP
aws ec2 authorize-security-group-ingress --group-id sg-0000000000000006 \
  --protocol tcp --port 53 --source-group sg-0000000000000008

# HTTPS
aws ec2 authorize-security-group-ingress --group-id sg-0000000000000006 \
  --protocol tcp --port 443 --source-group sg-0000000000000008
```

> **참고**: 노드가 Control Plane과 통신하기 위해 필수. DNS 조회 및 API Server 접근에 사용됨.

---

## 2026-01-22 PRD v1 환경 ALB → Node 보안 그룹 인바운드 규칙 추가 ✅

AWS Load Balancer Controller가 자동으로 관리하던 규칙을 삭제해서 서비스 장애 발생. 수동으로 규칙 복구.

### 원인
- LB Controller가 `target-type: instance` 사용 시 Node SG 규칙을 자동 관리
- 16:59 KST에 LB Controller가 NodePort 인바운드 규칙 삭제 → 전체 서비스 504 발생

### 보안 그룹 정보

| 구분 | Security Group ID | 이름 |
|------|-------------------|------|
| v1 Node SG | `sg-0000000000000007` | acme-main-prd-node-* |
| ALB SG 1 | `sg-0000000000000003` | k8s-traffic-acmemainprd-* |
| ALB SG 2 | `sg-0000000000000005` | k8s-istioing-istioing-* |

### 추가된 규칙 (Node SG)

| 규칙 ID | 프로토콜 | 포트 | 소스 | 설명 |
|---------|----------|------|------|------|
| `sgr-00000000000000004` | TCP | 30000-32767 | ALB SG 1 | NodePort from ALB |
| `sgr-00000000000000005` | TCP | 30000-32767 | ALB SG 2 | NodePort from ALB |

### 실행한 명령어

```bash
export AWS_PROFILE=prd

# ALB SG 1 → Node SG (NodePort)
aws ec2 authorize-security-group-ingress --group-id sg-0000000000000007 \
  --protocol tcp --port 30000-32767 --source-group sg-0000000000000003

# ALB SG 2 → Node SG (NodePort)
aws ec2 authorize-security-group-ingress --group-id sg-0000000000000007 \
  --protocol tcp --port 30000-32767 --source-group sg-0000000000000005
```

### LB Controller 규칙 관리 비활성화

LB Controller가 다시 규칙을 삭제하지 않도록 Ingress에 어노테이션 추가:

```bash
kubectl annotate ingress istio-ingress -n istio-ingress \
  "alb.ingress.kubernetes.io/manage-backend-security-group-rules=false" --overwrite
```

> **중요**: 이 어노테이션은 Git 레포(`feat/dev/v2/cicd` 브랜치, `./manifests/ingress/prd/`)에도 반영 필요. ArgoCD sync 시 덮어쓰일 수 있음.

---
