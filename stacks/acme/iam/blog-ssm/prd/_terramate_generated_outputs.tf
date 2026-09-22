// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

output "instance_profile_name" {
  description = "blog EC2에 연결할 인스턴스 프로파일 이름"
  value       = aws_iam_instance_profile.blog_ssm.name
}
output "instance_profile_arn" {
  description = "인스턴스 프로파일 ARN"
  value       = aws_iam_instance_profile.blog_ssm.arn
}
output "session_log_group_name" {
  description = "세션 문서 cloudWatchLogGroupName에 설정할 로그그룹 이름"
  value       = aws_cloudwatch_log_group.ssm_sessions.name
}
