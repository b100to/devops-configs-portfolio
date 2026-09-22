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
resource "aws_s3_bucket" "cloudtrail" {
  bucket = local.bucket_name
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  block_public_acls       = true
  block_public_policy     = true
  bucket                  = aws_s3_bucket.cloudtrail.id
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    expiration {
      days = var.s3_lifecycle_days
    }
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:ap-northeast-2:${var.account_id}:trail/${var.trail_name}"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${var.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cloudtrail:ap-northeast-2:${var.account_id}:trail/${var.trail_name}"
          }
        }
      },
    ]
  })
}
resource "aws_cloudtrail" "main" {
  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
  ]
  enable_logging                = true
  include_global_service_events = true
  is_multi_region_trail         = true
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_sns_topic" "alerts" {
  name = local.sns_topic_name
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
    ]
  })
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
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}
resource "aws_lambda_function" "slack_notifier" {
  filename         = data.archive_file.lambda.output_path
  function_name    = local.lambda_name
  handler          = "index.handler"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
  timeout = 10
  environment {
    variables = {
      SLACK_BOT_TOKEN = data.aws_secretsmanager_secret_version.slack_bot_token.secret_string
      SLACK_CHANNEL   = var.slack_channel
      ENVIRONMENT     = var.environment
      ALLOWED_IPS     = jsonencode(var.allowed_ips)
    }
  }
}
resource "aws_sns_topic_subscription" "lambda" {
  endpoint  = aws_lambda_function.slack_notifier.arn
  protocol  = "lambda"
  topic_arn = aws_sns_topic.alerts.arn
}
resource "aws_lambda_permission" "sns" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
  statement_id  = "AllowSNSInvoke"
}
resource "aws_cloudwatch_event_rule" "alerts" {
  description   = each.value.description
  event_pattern = each.value.pattern
  for_each      = local.alert_rules
  name          = "cloudtrail-${each.key}-${var.environment}"
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_cloudwatch_event_target" "sns" {
  arn       = aws_sns_topic.alerts.arn
  for_each  = local.alert_rules
  rule      = aws_cloudwatch_event_rule.alerts[each.key].name
  target_id = "sns-${each.key}"
}
provider "aws" {
  alias   = "us_east_1"
  profile = "dev"
  region  = "us-east-1"
}
resource "aws_iam_role" "eventbridge_forwarder" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  name = "cloudtrail-events-forwarder-${var.environment}"
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role_policy" "eventbridge_forwarder" {
  name = "put-events-target-region"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = "arn:aws:events:ap-northeast-2:${var.account_id}:event-bus/default"
      },
    ]
  })
  role = aws_iam_role.eventbridge_forwarder.id
}
resource "aws_cloudwatch_event_rule" "global_alerts" {
  description   = "${each.value.description} (forwarded)"
  event_pattern = each.value.pattern
  for_each      = local.global_rules
  name          = "cloudtrail-${each.key}-${var.environment}"
  provider      = aws.us_east_1
  tags = {
    CreatedBy   = "terraform"
    Environment = "dev"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_cloudwatch_event_target" "forward_to_home_region" {
  arn       = "arn:aws:events:ap-northeast-2:${var.account_id}:event-bus/default"
  for_each  = local.global_rules
  provider  = aws.us_east_1
  role_arn  = aws_iam_role.eventbridge_forwarder.arn
  rule      = aws_cloudwatch_event_rule.global_alerts[each.key].name
  target_id = "forward-${each.key}"
}
