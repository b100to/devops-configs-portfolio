stack {
  name = "oidc_aws_github_dev"
  id   = "oidc_aws_github_dev"
  tags = ["oidc", "aws", "github", "dev", "local"]
  before = [
    "tag:dev:stack"
  ]
}