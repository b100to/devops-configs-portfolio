locals {
  repositories = toset([
    "common-user-service-dev",
    "partner-django-admin-dev",
    "micro-beacon-service-dev",
    "micro-member-service-dev",
    "venue-admin-acme-dev",
    "venue-admin-partner-dev",
    "venue-partner-admin-dev",
    "venue-partner-user-dev",
    "play-recommendation-dev",
    "play-service-dev",
    "sc-ins-dev",
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
