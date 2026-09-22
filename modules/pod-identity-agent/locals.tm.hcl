generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      current_date = formatdate("YYYYMMDD", timestamp())

      role_name = "eks-pod-identity-${var.service_account}-${global.version}"

      policy_name = "eks-pod-identity-${var.service_account}-${global.version}"
      policy      = file("${path.module}/policy.json")

      # IAM 정책 문서와 같이 복잡한 구조는 locals에서 관리
      assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
              Service = ["pods.eks.amazonaws.com"]
            }
            Action = [
              "sts:AssumeRole",
              "sts:TagSession"
            ]
          }
        ]
      })
    }
  }
}
