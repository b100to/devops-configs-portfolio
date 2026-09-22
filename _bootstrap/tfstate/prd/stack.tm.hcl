stack {
  name = "tfstate_prd"
  id   = "tfstate_prd"
  tags = ["aws", "tfstate", "prd", "local"]

  before = ["tag:prd:stack"]
}