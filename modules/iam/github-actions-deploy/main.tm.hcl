generate_hcl "_terramate_generated_main.tf" {
  content {
    data "aws_caller_identity" "current" {}

    # GitHubActions-Deploy IAM Role for acme-data DAG deployment
    resource "aws_iam_role" "github_actions_deploy" {
      name = "GitHubActions-Deploy"

      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
            }
            Action = "sts:AssumeRoleWithWebIdentity"
            Condition = {
              StringEquals = {
                "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
              }
              StringLike = {
                "token.actions.githubusercontent.com:sub" = "repo:AcmeCorp/acme-data:ref:refs/heads/main"
              }
            }
          }
        ]
      })
    }

    resource "aws_iam_role_policy" "github_actions_deploy" {
      name = "airflow-dag-deploy"
      role = aws_iam_role.github_actions_deploy.id

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "EKSAccess"
            Effect = "Allow"
            Action = [
              "eks:DescribeCluster",
              "eks:ListClusters"
            ]
            Resource = [
              "arn:aws:eks:ap-northeast-2:${data.aws_caller_identity.current.account_id}:cluster/acme-main-v2-prd"
            ]
          },
          {
            Sid    = "EFSAccess"
            Effect = "Allow"
            Action = [
              "elasticfilesystem:DescribeFileSystems",
              "elasticfilesystem:CreateFileSystem",
              "elasticfilesystem:CreateMountTarget",
              "elasticfilesystem:DescribeMountTargets"
            ]
            Resource = "*"
          },
          {
            Sid    = "EC2Access"
            Effect = "Allow"
            Action = [
              "ec2:DescribeInstances",
              "ec2:DescribeSubnets",
              "ec2:DescribeVpcs",
              "ec2:CreateSecurityGroup",
              "ec2:AuthorizeSecurityGroupIngress",
              "ec2:DescribeSecurityGroups"
            ]
            Resource = "*"
          },
          {
            Sid    = "AirflowGreenConnectionBundleRead"
            Effect = "Allow"
            Action = [
              "secretsmanager:GetSecretValue"
            ]
            Resource = [
              "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:airflow/connections/core-*",
              "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:airflow/connections/mall-*",
              "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:airflow/connections/partner1-*",
              "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:airflow/connections/recommendation-*"
            ]
          }
        ]
      })
    }

    resource "aws_eks_access_entry" "github_actions_deploy_v2" {
      cluster_name  = "acme-main-v2-prd"
      principal_arn = aws_iam_role.github_actions_deploy.arn
      type          = "STANDARD"
    }

    resource "aws_eks_access_policy_association" "github_actions_deploy_v2" {
      cluster_name  = "acme-main-v2-prd"
      principal_arn = aws_iam_role.github_actions_deploy.arn
      policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

      access_scope {
        type       = "cluster"
        namespaces = null
      }
    }
  }
}
