// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

resource "aws_guardduty_detector" "main" {
  enable                       = false
  finding_publishing_frequency = var.finding_publishing_frequency
  tags = {
    CreatedBy   = "terraform"
    Environment = "prd"
    Project     = "acme"
    Team        = "DevOps"
  }
}
