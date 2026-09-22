generate_hcl "_terramate_generated_main.tf" {
  content {
    # SageMaker Studio ExecutionRole
    # 두 SageMaker 도메인(canvas-sageMaker, default-1651060317941)이 이 역할을 참조함
    resource "aws_iam_role" "this" {
      name = "AmazonSageMaker-ExecutionRole-20220407T160147"
      path = "/service-role/"

      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              Service = "sagemaker.amazonaws.com"
            }
            Action = "sts:AssumeRole"
          }
        ]
      })

      tags = global.tags
    }

    resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
      role       = aws_iam_role.this.name
      policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
    }

    resource "aws_iam_role_policy_attachment" "s3_full_access" {
      role       = aws_iam_role.this.name
      policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    }
  }
}
