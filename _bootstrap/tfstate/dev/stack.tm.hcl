stack {
  name   = "tfstate_dev"
  id     = "tfstate_dev"
  tags   = ["aws", "tfstate", "dev", "local"]
  before = ["tag:dev:stack"]
}