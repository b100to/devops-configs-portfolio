generate_hcl "_terramate_generated_main.tf" {
  content {
    # --- Data Sources ---

    data "aws_secretsmanager_secret_version" "slack_bot_token" {
      secret_id = var.slack_bot_token_secret_name
    }

    data "archive_file" "lambda" {
      type        = "zip"
      output_path = "${path.module}/lambda.zip"

      source {
        content  = local.lambda_code
        filename = "index.py"
      }
    }

    # --- Lambda IAM Role ---

    resource "aws_iam_role" "lambda" {
      name = "${local.lambda_name}-role"

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

      tags = global.tags
    }

    resource "aws_iam_role_policy" "lambda" {
      name = "${local.lambda_name}-policy"
      role = aws_iam_role.lambda.id

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid      = "EKSDescribe"
            Effect   = "Allow"
            Action   = "eks:DescribeCluster"
            Resource = "arn:aws:eks:${global.region}:${var.account_id}:cluster/${var.cluster_name}"
          },
          {
            Sid      = "LambdaSelfInvoke"
            Effect   = "Allow"
            Action   = "lambda:InvokeFunction"
            Resource = local.lambda_arn
          },
          {
            Sid      = "SSMSession"
            Effect   = "Allow"
            Action   = ["ssm:GetParameter", "ssm:PutParameter"]
            Resource = "arn:aws:ssm:${global.region}:${var.account_id}:parameter/dev-scaler/*"
          },
          {
            Sid    = "Scheduler"
            Effect = "Allow"
            Action = [
              "scheduler:CreateSchedule",
              "scheduler:DeleteSchedule",
              "scheduler:GetSchedule",
            ]
            Resource = "arn:aws:scheduler:${global.region}:${var.account_id}:schedule/${local.schedule_group}/*"
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
    }

    # --- Lambda Function ---

    resource "aws_lambda_function" "scaler" {
      function_name    = local.lambda_name
      role             = aws_iam_role.lambda.arn
      handler          = "index.handler"
      runtime          = "python3.12"
      timeout          = 360
      memory_size      = 256
      filename         = data.archive_file.lambda.output_path
      source_code_hash = data.archive_file.lambda.output_base64sha256

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

      tags = global.tags
    }

    # --- Lambda Function URL (for Slack slash command) ---

    resource "aws_lambda_function_url" "scaler" {
      function_name      = aws_lambda_function.scaler.function_name
      authorization_type = "NONE"
    }

    # --- EventBridge Scheduler IAM ---

    resource "aws_iam_role" "scheduler" {
      name = "${local.lambda_name}-scheduler-role"

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

      tags = global.tags
    }

    resource "aws_iam_role_policy" "scheduler" {
      name = "${local.lambda_name}-scheduler-policy"
      role = aws_iam_role.scheduler.id

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
    }

    # --- EventBridge Schedule Group ---

    resource "aws_scheduler_schedule_group" "scaler" {
      name = local.schedule_group
      tags = global.tags
    }

    # --- Schedules (Mon-Fri KST) ---

    resource "aws_scheduler_schedule" "scale_up" {
      name       = "scale-up"
      group_name = aws_scheduler_schedule_group.scaler.name

      schedule_expression          = var.scale_up_schedule
      schedule_expression_timezone = "Asia/Seoul"

      flexible_time_window {
        mode = "OFF"
      }

      target {
        arn      = aws_lambda_function.scaler.arn
        role_arn = aws_iam_role.scheduler.arn
        input    = jsonencode({ source = "self", action = "scale_up" })
      }
    }

    resource "aws_scheduler_schedule" "scale_down" {
      name       = "scale-down"
      group_name = aws_scheduler_schedule_group.scaler.name

      schedule_expression          = var.scale_down_schedule
      schedule_expression_timezone = "Asia/Seoul"

      flexible_time_window {
        mode = "OFF"
      }

      target {
        arn      = aws_lambda_function.scaler.arn
        role_arn = aws_iam_role.scheduler.arn
        input    = jsonencode({ source = "self", action = "scale_down" })
      }
    }

    # --- SSM Parameter (session state) ---

    resource "aws_ssm_parameter" "session" {
      name  = "/dev-scaler/session"
      type  = "String"
      value = "{}"

      lifecycle {
        ignore_changes = [value]
      }

      tags = global.tags
    }

    resource "aws_ssm_parameter" "original_limits" {
      name  = "/dev-scaler/original-limits"
      type  = "String"
      value = "{}"

      lifecycle {
        ignore_changes = [value]
      }

      tags = global.tags
    }
  }
}
