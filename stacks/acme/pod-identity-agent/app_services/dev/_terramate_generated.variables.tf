// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

variable "namespace" {
  default     = "kube-system"
  description = "설치될 네임스페이스"
  type        = string
}
variable "service_account" {
  description = "서비스 어카운트 이름 (Role/Policy 이름에 사용)"
  type        = string
}
variable "service_accounts" {
  default = [
  ]
  description = "PIA에 연결할 서비스 어카운트 목록 (비어있으면 service_account 사용)"
  type        = list(string)
}
