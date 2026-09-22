stack {
  name = "oidc_aws_github_prd"
  id   = "oidc_aws_github_prd"
  tags = ["oidc", "aws", "github", "prd", "local"]
  before = [
    "tag:dev:stack"
  ]
}