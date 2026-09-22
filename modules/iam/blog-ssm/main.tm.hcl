generate_hcl "_terramate_generated_main.tf" {
  content {
    # SSM Session Manager 세션 로그용 CloudWatch 로그그룹 (ISMS 로그·감사)
    # - 계정 전역 세션 문서(SSM-SessionManagerRunShell)의 cloudWatchLogGroupName이 이 그룹을 가리킴
    # - 저장 데이터는 CloudWatch 기본 암호화(AES-256)로 보호됨
    resource "aws_cloudwatch_log_group" "ssm_sessions" {
      name              = var.session_log_group_name
      retention_in_days = var.session_log_retention_days
      tags              = global.tags
    }

    # blog EC2(베스천)용 IAM 역할 — EC2가 SSM에 등록되기 위한 신뢰관계
    resource "aws_iam_role" "blog_ssm" {
      name = var.role_name

      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect    = "Allow"
            Principal = { Service = "ec2.amazonaws.com" }
            Action    = "sts:AssumeRole"
          }
        ]
      })

      tags = global.tags
    }

    # SSM 코어 권한 (agent 등록, 세션 채널)
    resource "aws_iam_role_policy_attachment" "ssm_core" {
      role       = aws_iam_role.blog_ssm.name
      policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }

    # 최소권한 CloudWatch Logs 쓰기 — 세션 로그그룹으로만 스코핑
    resource "aws_iam_role_policy" "session_logs" {
      name = "ssm-session-logs"
      role = aws_iam_role.blog_ssm.id

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
            Effect   = "Allow"
            Action   = ["logs:DescribeLogGroups"]
            Resource = "*"
          },
        ]
      })
    }

    # blog EC2에 연결할 인스턴스 프로파일 (연결은 apply 후 CLI 1회성 — blog는 TF 미관리)
    resource "aws_iam_instance_profile" "blog_ssm" {
      name = var.instance_profile_name
      role = aws_iam_role.blog_ssm.name
      tags = global.tags
    }
  }
}
