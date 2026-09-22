locals {
  repositories = toset([
    "acme-recommendation-api-prod",
    "acmemall-backend-prod",
    "acmemall-backend-v4/prd/api",
    "acmemall-backend-v4/prd/api-admin",
    "acmemall-backend-v4/prd/api-seller",
    "acmemall-backend-v4/prd/batch",
    "acmemall-backend-v4/prd/consumer",
  ])
}

resource "aws_ecr_repository" "this" {
  for_each             = local.repositories
  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = each.value
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}
