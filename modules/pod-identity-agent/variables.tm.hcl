generate_hcl "_terramate_generated.variables.tf" {
  content {
    variable "namespace" {
      description = "설치될 네임스페이스"
      type        = string
      default     = "kube-system"
    }

    variable "service_account" {
      description = "서비스 어카운트 이름 (Role/Policy 이름에 사용)"
      type        = string
    }

    variable "service_accounts" {
      description = "PIA에 연결할 서비스 어카운트 목록 (비어있으면 service_account 사용)"
      type        = list(string)
      default     = []
    }
  }
}