// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "aws_secretsmanager_secret_version" "slack_bot_token" {
  secret_id = var.slack_bot_token_secret_name
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
    Environment = "dev"
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
        Sid      = "EKSDescribe"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = "arn:aws:eks:ap-northeast-2:${var.account_id}:cluster/${var.cluster_name}"
      },
      {
        Sid      = "LambdaSelfInvoke"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = local.lambda_arn
      },
      {
        Sid    = "SSMSession"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter",
        ]
        Resource = "arn:aws:ssm:ap-northeast-2:${var.account_id}:parameter/dev-scaler/*"
      },
      {
        Sid    = "Scheduler"
        Effect = "Allow"
        Action = [
          "scheduler:CreateSchedule",
          "scheduler:DeleteSchedule",
          "scheduler:GetSchedule",
        ]
        Resource = "arn:aws:scheduler:ap-northeast-2:${var.account_id}:schedule/${local.schedule_group}/*"
      },
      {
        Sid      = "PassSchedulerRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.scheduler.arn
      },
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
        Sid      = "STS"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
    ]
  })
  role = aws_iam_role.lambda.id
}
resource "aws_lambda_function" "scaler" {
  filename         = data.archive_file.lambda.output_path
  function_name    = local.lambda_name
  handler          = "index.handler"
  memory_size      = 256
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
  timeout = 360
  environment {
    variables = {
      CLUSTER_NAME       = var.cluster_name
      SLACK_BOT_TOKEN    = data.aws_secretsmanager_secret_version.slack_bot_token.secret_string
      SLACK_CHANNEL      = var.slack_channel
      LAMBDA_ARN         = local.lambda_arn
      SCHEDULER_ROLE_ARN = aws_iam_role.scheduler.arn
      NODEPOOLS_CONFIG   = var.nodepools_config
    }
  }
}
resource "aws_lambda_function_url" "scaler" {
  authorization_type = "NONE"
  function_name      = aws_lambda_function.scaler.function_name
}
resource "aws_iam_role" "scheduler" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  name = "${local.lambda_name}-scheduler-role"
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role_policy" "scheduler" {
  name = "${local.lambda_name}-scheduler-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = local.lambda_arn
      },
    ]
  })
  role = aws_iam_role.scheduler.id
}
resource "aws_scheduler_schedule_group" "scaler" {
  name = local.schedule_group
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_scheduler_schedule" "scale_up" {
  group_name                   = aws_scheduler_schedule_group.scaler.name
  name                         = "scale-up"
  schedule_expression          = var.scale_up_schedule
  schedule_expression_timezone = "Asia/Seoul"
  flexible_time_window {
    mode = "OFF"
  }
  target {
    arn = aws_lambda_function.scaler.arn
    input = jsonencode({
      source = "self"
      action = "scale_up"
    })
    role_arn = aws_iam_role.scheduler.arn
  }
}
resource "aws_scheduler_schedule" "scale_down" {
  group_name                   = aws_scheduler_schedule_group.scaler.name
  name                         = "scale-down"
  schedule_expression          = var.scale_down_schedule
  schedule_expression_timezone = "Asia/Seoul"
  flexible_time_window {
    mode = "OFF"
  }
  target {
    arn = aws_lambda_function.scaler.arn
    input = jsonencode({
      source = "self"
      action = "scale_down"
    })
    role_arn = aws_iam_role.scheduler.arn
  }
}
resource "aws_ssm_parameter" "session" {
  name = "/dev-scaler/session"
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
  type  = "String"
  value = "{}"
  lifecycle {
    ignore_changes = [
      value,
    ]
  }
}
resource "aws_ssm_parameter" "original_limits" {
  name = "/dev-scaler/original-limits"
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
  type  = "String"
  value = "{}"
  lifecycle {
    ignore_changes = [
      value,
    ]
  }
}
