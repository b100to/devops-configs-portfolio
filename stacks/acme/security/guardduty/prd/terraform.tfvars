# 2026-06-22: detector가 콘솔에서 수동 삭제되어(샘플 findings 정리 목적) state와 드리프트 발생.
# 이 스택을 changed로 표시해 CI apply가 detector를 재생성(복구)하도록 한다.
# 2026-06-25: enable=false 적용 누락으로 CI re-trigger
environment = "prd"
account_id  = "222222222222"

finding_publishing_frequency = "FIFTEEN_MINUTES"
