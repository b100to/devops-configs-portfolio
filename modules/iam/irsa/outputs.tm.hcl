generate_hcl "_terramate_generated_outputs.tf" {
  content {
    output "role_arn" {
      description = "ARN of IRSA IAM role"
      value       = aws_iam_role.this.arn
    }
  }
}
