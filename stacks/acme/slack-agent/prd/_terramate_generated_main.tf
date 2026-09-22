// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "aws_secretsmanager_secret_version" "config" {
  secret_id = var.secret_name
}
data "archive_file" "lambda" {
  output_path = "${path.module}/lambda.zip"
  type        = "zip"
  source {
    content  = local.lambda_code
    filename = "index.py"
  }
}
resource "aws_iam_role" "lambda" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  name = "${local.lambda_name}-role"
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role_policy" "lambda" {
  name = "${local.lambda_name}-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "*"
      },
      {
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = "arn:aws:secretsmanager:ap-northeast-2:${var.account_id}:secret:${var.secret_name}-*"
      },
      {
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = "arn:aws:eks:ap-northeast-2:${var.account_id}:cluster/${var.cluster_name}"
      },
      {
        Sid      = "STS"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
      {
        Sid      = "LambdaSelfInvoke"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = local.lambda_arn
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
      {
        Sid      = "AssumeDevRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = var.dev_cross_account_role_arn != "" ? var.dev_cross_account_role_arn : "arn:aws:iam::000000000000:role/dummy"
      },
    ]
  })
  role = aws_iam_role.lambda.id
}
resource "aws_lambda_function" "agent" {
  filename         = data.archive_file.lambda.output_path
  function_name    = local.lambda_name
  handler          = "index.handler"
  memory_size      = 256
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
  timeout = 120
  environment {
    variables = {
      SECRET_NAME            = var.secret_name
      CLUSTER_NAME           = var.cluster_name
      ENVIRONMENT            = var.environment
      ZAI_MODEL              = var.zai_model
      DEV_CROSS_ACCOUNT_ROLE = var.dev_cross_account_role_arn
    }
  }
}
resource "aws_lambda_function_url" "agent" {
  authorization_type = "NONE"
  function_name      = aws_lambda_function.agent.function_name
}
