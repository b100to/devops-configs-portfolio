# =============================================================================
# Slack Agent Cross-Account Role (dev)
# - prd Lambda가 dev 계정 리소스(EKS, EC2, RDS 등)를 읽기 위한 역할
# - prd Lambda Role ARN: arn:aws:iam::222222222222:role/slack-agent-prd-role
# =============================================================================

locals {
  prd_lambda_role_arn = "arn:aws:iam::222222222222:role/slack-agent-prd-role"
}

resource "aws_iam_role" "slack_agent_cross_account" {
  name = "slack-agent-cross-account"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.prd_lambda_role_arn
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = {
    Service     = "slack-agent"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "slack_agent_read" {
  name = "slack-agent-read-policy"
  role = aws_iam_role.slack_agent_cross_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKS"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
        ]
        Resource = "arn:aws:eks:ap-northeast-2:111111111111:cluster/acme-main-v2-dev"
      },
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
      {
        Sid    = "AWSRead"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
        ]
        Resource = "*"
      },
    ]
  })
}

# EKS access entry for cross-account role
resource "aws_eks_access_entry" "slack_agent" {
  cluster_name  = "acme-main-v2-dev"
  principal_arn = aws_iam_role.slack_agent_cross_account.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "slack_agent" {
  cluster_name  = "acme-main-v2-dev"
  principal_arn = aws_iam_role.slack_agent_cross_account.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "cluster"
  }
}
