// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_cloudwatch_log_group" "ssm_sessions" {
  name              = var.session_log_group_name
  retention_in_days = var.session_log_retention_days
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role" "blog_ssm" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
  name = var.role_name
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
resource "aws_iam_role_policy_attachment" "ssm_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.blog_ssm.name
}
resource "aws_iam_role_policy" "session_logs" {
  name = "ssm-session-logs"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = "${aws_cloudwatch_log_group.ssm_sessions.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
        ]
        Resource = "*"
      },
    ]
  })
  role = aws_iam_role.blog_ssm.id
}
resource "aws_iam_instance_profile" "blog_ssm" {
  name = var.instance_profile_name
  role = aws_iam_role.blog_ssm.name
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
