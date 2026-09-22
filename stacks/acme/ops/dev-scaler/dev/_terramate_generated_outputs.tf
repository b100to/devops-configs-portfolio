// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

output "function_url" {
  description = "Lambda Function URL for Slack slash command"
  value       = aws_lambda_function_url.scaler.function_url
}
output "lambda_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.scaler.arn
}
output "lambda_role_arn" {
  description = "Lambda IAM role ARN (for EKS access entry)"
  value       = aws_iam_role.lambda.arn
}
