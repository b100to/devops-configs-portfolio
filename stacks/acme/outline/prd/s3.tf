# =============================================================================
# Outline - S3 File Storage + IRSA
# - 이미지/첨부파일(대용량 포함) 저장소를 local PVC → S3 로 전환
# - Outline Pod가 IRSA 기반으로 S3 접근 (KeyId/Secret 불필요)
# - CORS: wiki.acme.example 에서 presigned URL 업로드 허용
# =============================================================================

locals {
  s3_bucket_name = "acme-outline-prd"
  iam_role_name  = "irsa-outline-prd"
  k8s_namespace  = "outline"
  k8s_sa_name    = "outline"
}

# --- S3 Bucket ---

resource "aws_s3_bucket" "outline" {
  bucket = local.s3_bucket_name

  tags = {
    Service     = "outline"
    Environment = "prd"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "outline" {
  bucket = aws_s3_bucket.outline.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "outline" {
  bucket = aws_s3_bucket.outline.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "outline" {
  bucket = aws_s3_bucket.outline.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 브라우저가 S3 presigned URL로 직접 업로드/다운로드하므로 CORS 필요
resource "aws_s3_bucket_cors_configuration" "outline" {
  bucket = aws_s3_bucket.outline.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["https://wiki.acme.example"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# 실수로 삭제된 오브젝트 복구 가능하도록 30일 후 영구 삭제
resource "aws_s3_bucket_lifecycle_configuration" "outline" {
  bucket = aws_s3_bucket.outline.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- IRSA: Outline Pod → S3 ---

data "aws_iam_openid_connect_provider" "eks" {
  arn = var.oidc_provider_arn
}

locals {
  # "https://oidc.eks.ap-northeast-2.amazonaws.com/id/XXX" -> "oidc.eks.ap-northeast-2.amazonaws.com/id/XXX"
  oidc_issuer = replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")
}

data "aws_iam_policy_document" "outline_irsa_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${local.k8s_namespace}:${local.k8s_sa_name}"]
    }
  }
}

data "aws_iam_policy_document" "outline_s3" {
  statement {
    sid    = "S3BucketAccess"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [aws_s3_bucket.outline.arn]
  }

  statement {
    sid    = "S3ObjectAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]

    resources = ["${aws_s3_bucket.outline.arn}/*"]
  }
}

resource "aws_iam_role" "outline" {
  name               = local.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.outline_irsa_trust.json

  tags = {
    Service     = "outline"
    Environment = "prd"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "outline_s3" {
  name        = "${local.iam_role_name}-s3"
  description = "Outline Pod S3 access (file storage)"
  policy      = data.aws_iam_policy_document.outline_s3.json

  tags = {
    Service     = "outline"
    Environment = "prd"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "outline_s3" {
  role       = aws_iam_role.outline.name
  policy_arn = aws_iam_policy.outline_s3.arn
}
