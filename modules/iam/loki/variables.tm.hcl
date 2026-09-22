// variables.tm.hcl
generate_hcl "_terramate_generated_variables.tf" {
  content {
    variable "s3_versioning_enabled" {
      description = "S3 버킷 버전 관리 활성화 여부"
      type        = bool
      default     = true
    }

    variable "sse_algorithm" {
      description = "서버측 암호화 알고리즘"
      type        = string
      default     = "AES256"
    }
  }
}
