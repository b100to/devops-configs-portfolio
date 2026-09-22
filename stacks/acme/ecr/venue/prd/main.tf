locals {
  repositories = toset([
    "common-user-service-prod",
    "partner-django-admin-prod",
    "micro-beacon-service-prod",
    "micro-member-service-prod",
    "venue-admin-acme-prod",
    "venue-admin-partner-prod",
    "venue-partner-admin-prod",
    "venue-partner-user-prod",
    "play-recommendation-prod",
    "play-service-prod",
    "sc-ins-prod",
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
