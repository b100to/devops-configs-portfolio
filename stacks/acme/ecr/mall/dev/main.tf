locals {
  repositories = toset([
    "acmemall-backend-v4/dev/api",
    "acmemall-backend-v4/dev/api-admin",
    "acmemall-backend-v4/dev/api-seller",
    "acmemall-backend-v4/dev/batch",
    "acmemall-backend-v4/dev/consumer",
    "acmemall-backend-dev",
    "acme-recommendation-api-dev",
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
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
