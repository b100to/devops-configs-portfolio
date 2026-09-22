generate_hcl "_terramate_generated_.auto.tfvars" {
  content {
    enable_aws_efs_csi_driver = true
    enable_prefix_delegation  = true
  }
}
