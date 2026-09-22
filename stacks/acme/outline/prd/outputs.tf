output "secret_arn" {
  description = "outline/prd Secrets Manager ARN"
  value       = aws_secretsmanager_secret.outline.arn
}

output "s3_bucket_name" {
  description = "Outline file storage S3 bucket name"
  value       = aws_s3_bucket.outline.bucket
}

output "s3_bucket_url" {
  description = "Outline S3 bucket virtual-hosted URL (AWS_S3_UPLOAD_BUCKET_URL 용)"
  value       = "https://${aws_s3_bucket.outline.bucket}.s3.ap-northeast-2.amazonaws.com"
}

output "iam_role_arn" {
  description = "IRSA IAM role ARN (SA annotation 용)"
  value       = aws_iam_role.outline.arn
}
