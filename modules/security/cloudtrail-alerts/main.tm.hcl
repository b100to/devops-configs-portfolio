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

    # --- S3 Bucket for CloudTrail Logs ---

    resource "aws_s3_bucket" "cloudtrail" {
      bucket = local.bucket_name
      tags   = global.tags
    }

    resource "aws_s3_bucket_public_access_block" "cloudtrail" {
      bucket = aws_s3_bucket.cloudtrail.id

      block_public_acls       = true
      block_public_policy     = true
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
                "aws:SourceArn" = "arn:aws:cloudtrail:${global.region}:${var.account_id}:trail/${var.trail_name}"
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
                "aws:SourceArn" = "arn:aws:cloudtrail:${global.region}:${var.account_id}:trail/${var.trail_name}"
              }
            }
          },
        ]
      })
    }

    # --- CloudTrail ---

    resource "aws_cloudtrail" "main" {
      name                          = var.trail_name
      s3_bucket_name                = aws_s3_bucket.cloudtrail.id
      is_multi_region_trail         = true
      include_global_service_events = true
      enable_logging                = true

      tags = global.tags

      depends_on = [aws_s3_bucket_policy.cloudtrail]
    }

    # --- SNS Topic ---

    resource "aws_sns_topic" "alerts" {
      name = local.sns_topic_name
      tags = global.tags
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

    # --- Lambda Function ---

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

    resource "aws_iam_role_policy_attachment" "lambda_logs" {
      role       = aws_iam_role.lambda.name
      policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    }

    resource "aws_lambda_function" "slack_notifier" {
      function_name    = local.lambda_name
      role             = aws_iam_role.lambda.arn
      handler          = "index.handler"
      runtime          = "python3.12"
      timeout          = 10
      filename         = data.archive_file.lambda.output_path
      source_code_hash = data.archive_file.lambda.output_base64sha256

      environment {
        variables = {
          SLACK_BOT_TOKEN = data.aws_secretsmanager_secret_version.slack_bot_token.secret_string
          SLACK_CHANNEL   = var.slack_channel
          ENVIRONMENT     = var.environment
          ALLOWED_IPS     = jsonencode(var.allowed_ips)
        }
      }

      tags = global.tags
    }

    resource "aws_sns_topic_subscription" "lambda" {
      topic_arn = aws_sns_topic.alerts.arn
      protocol  = "lambda"
      endpoint  = aws_lambda_function.slack_notifier.arn
    }

    resource "aws_lambda_permission" "sns" {
      statement_id  = "AllowSNSInvoke"
      action        = "lambda:InvokeFunction"
      function_name = aws_lambda_function.slack_notifier.function_name
      principal     = "sns.amazonaws.com"
      source_arn    = aws_sns_topic.alerts.arn
    }

    # --- EventBridge Rules ---

    resource "aws_cloudwatch_event_rule" "alerts" {
      for_each = local.alert_rules

      name          = "cloudtrail-${each.key}-${var.environment}"
      description   = each.value.description
      event_pattern = each.value.pattern
      tags          = global.tags
    }

    resource "aws_cloudwatch_event_target" "sns" {
      for_each = local.alert_rules

      rule      = aws_cloudwatch_event_rule.alerts[each.key].name
      target_id = "sns-${each.key}"
      arn       = aws_sns_topic.alerts.arn
    }

    # --- us-east-1: Global Service Events (IAM, Console Sign-In) ---
    # Global AWS services emit EventBridge events only in us-east-1.
    # Forward them to ap-northeast-2 where existing rules process them.

    provider "aws" {
      alias   = "us_east_1"
      region  = "us-east-1"
      profile = global.environment
    }

    resource "aws_iam_role" "eventbridge_forwarder" {
      name = "cloudtrail-events-forwarder-${var.environment}"

      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect    = "Allow"
          Principal = { Service = "events.amazonaws.com" }
          Action    = "sts:AssumeRole"
        }]
      })

      tags = global.tags
    }

    resource "aws_iam_role_policy" "eventbridge_forwarder" {
      name = "put-events-target-region"
      role = aws_iam_role.eventbridge_forwarder.id

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = "events:PutEvents"
          Resource = "arn:aws:events:${global.region}:${var.account_id}:event-bus/default"
        }]
      })
    }

    resource "aws_cloudwatch_event_rule" "global_alerts" {
      provider = aws.us_east_1
      for_each = local.global_rules

      name          = "cloudtrail-${each.key}-${var.environment}"
      description   = "${each.value.description} (forwarded)"
      event_pattern = each.value.pattern
      tags          = global.tags
    }

    resource "aws_cloudwatch_event_target" "forward_to_home_region" {
      provider = aws.us_east_1
      for_each = local.global_rules

      rule      = aws_cloudwatch_event_rule.global_alerts[each.key].name
      target_id = "forward-${each.key}"
      arn       = "arn:aws:events:${global.region}:${var.account_id}:event-bus/default"
      role_arn  = aws_iam_role.eventbridge_forwarder.arn
    }
  }
}
