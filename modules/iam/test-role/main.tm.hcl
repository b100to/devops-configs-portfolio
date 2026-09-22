generate_hcl "_terramate_generated_main.tf" {
  content {
    # 테스트 완료로 리소스 제거 (destroy) — CI apply 후 모듈/스택 디렉토리도 삭제 예정
  }
}
