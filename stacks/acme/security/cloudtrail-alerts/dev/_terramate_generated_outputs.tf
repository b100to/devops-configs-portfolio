// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

output "trail_arn" {
  description = "CloudTrail trail ARN"
  value       = aws_cloudtrail.main.arn
}
output "bucket_arn" {
  description = "S3 bucket ARN for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.arn
}
output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}
output "lambda_arn" {
  description = "Lambda function ARN for Slack notifications"
  value       = aws_lambda_function.slack_notifier.arn
}
