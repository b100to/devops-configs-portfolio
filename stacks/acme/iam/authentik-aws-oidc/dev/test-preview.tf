# PR preview 파이프라인 검증용 임시 리소스 (#348 레이스 픽스 동작 확인)
# 프리뷰 확인 후 제거 예정 — 실제 서비스와 무관
resource "aws_ssm_parameter" "preview_test" {
  name  = "/devops/test/pr-preview-check"
  type  = "String"
  value = "preview-test"

  tags = {
    Purpose = "ci-preview-test"
  }
}
