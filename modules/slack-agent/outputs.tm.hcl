generate_hcl "_terramate_generated_outputs.tf" {
  content {
    output "function_url" {
      description = "Lambda Function URL for Slack Event Subscriptions"
      value       = aws_lambda_function_url.agent.function_url
    }

    output "lambda_arn" {
      description = "Lambda function ARN"
      value       = aws_lambda_function.agent.arn
    }

    output "lambda_role_arn" {
      description = "Lambda IAM role ARN (for EKS access entry)"
      value       = aws_iam_role.lambda.arn
    }
  }
}
