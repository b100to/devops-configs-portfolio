generate_hcl "_terramate_generated_main.tf" {
  content {
    # AWS GuardDuty Detector
    # 정부(보안 점검) 요청으로 위협 탐지 활성화. 리전별 리소스이며
    # 현재 사용 리전(ap-northeast-2)에만 활성화한다.
    # 모든 데이터소스(VPC Flow Logs, DNS logs, CloudTrail events)는 기본 활성화.
    resource "aws_guardduty_detector" "main" {
      enable                       = false
      finding_publishing_frequency = var.finding_publishing_frequency

      tags = global.tags
    }
  }
}
