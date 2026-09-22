generate_hcl "_terramate_generated_tfvars.auto.tfvars" {
  content {
    name      = "acme"
    nat_count = 2

    intra_subnets = [
      "10.0.32.0/20",
      "10.0.80.0/20",
    ]

    single_nat_gateway     = false
    one_nat_gateway_per_az = true
  }
}
