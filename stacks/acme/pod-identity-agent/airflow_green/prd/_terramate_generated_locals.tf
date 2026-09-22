// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "pods.eks.amazonaws.com",
          ]
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession",
        ]
      },
    ]
  })
  current_date = formatdate("YYYYMMDD", timestamp())
  policy       = file("${path.module}/policy.json")
  policy_name  = "eks-pod-identity-${var.service_account}-v2"
  role_name    = "eks-pod-identity-${var.service_account}-v2"
}
