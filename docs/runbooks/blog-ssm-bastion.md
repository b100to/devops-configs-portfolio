# blog EC2 — SSM Session Manager 접속 (키리스 베스천)

prd `blog` EC2(`i-0000000000000001`)에 **SSH 키·22 포트 없이** AWS SSM Session Manager로 접속한다.

> 키 없음 · 인바운드 포트 없음 · 접속 전체가 CloudWatch에 감사 로깅됨 (ISMS 로그·감사).

## 구성 요소

| 요소 | 위치 | 비고 |
|------|------|------|
| IAM role + 인스턴스 프로파일 | `stacks/acme/iam/blog-ssm/prd` (Terraform) | `AmazonSSMManagedInstanceCore` + 로그 쓰기 |
| 세션 로그그룹 | CloudWatch `/aws/ssm/session-logs/prd` | 보존 365일, AES-256 |
| 세션 로깅 설정 | 계정 전역 문서 `SSM-SessionManagerRunShell` | `cloudWatchLogGroupName` 채워야 적용 (1회성) |
| 네트워크 | private 서브넷 + NAT gateway | 이미 충족 (VPC 엔드포인트 불필요) |

## 최초 셋업 (apply 후 1회성)

Terraform 스택이 apply되어 role/profile/로그그룹이 생성된 뒤 실행한다.

```bash
# 1) blog EC2에 인스턴스 프로파일 연결 (blog는 TF 미관리라 CLI로 1회 연결)
aws ec2 associate-iam-instance-profile --profile prd --region ap-northeast-2 \
  --instance-id i-0000000000000001 \
  --iam-instance-profile Name=blog-ssm-profile

# 2) 세션 문서에 로그 목적지 설정 (기존 필드 보존 + cloudWatchLogGroupName만 채움)
#    현재 문서 내용을 받아 cloudWatchLogGroupName 값만 바꿔 update-document 한다.

# 3) (필요 시) SSM agent 미설치/구버전이면 blog 안에서 설치
#    sudo systemctl status amazon-ssm-agent  → 없으면 OS별 설치
```

## 등록 확인

```bash
aws ssm describe-instance-information --profile prd --region ap-northeast-2 \
  --filters "Key=InstanceIds,Values=i-0000000000000001" \
  --query 'InstanceInformationList[].{Id:InstanceId,Ping:PingStatus,Agent:AgentVersion}'
```
`PingStatus: Online` 이면 준비 완료.

## 접속

```bash
# 셸 접속
aws ssm start-session --target i-0000000000000001 --profile prd --region ap-northeast-2

# 포트포워딩 (예: 내부 서비스 8080 → 로컬 18080)
aws ssm start-session --target i-0000000000000001 --profile prd --region ap-northeast-2 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["18080"]}'
```

> 로컬에 `session-manager-plugin` 필요 (`session-manager-plugin --version`). 없으면 `brew install --cask session-manager-plugin`.

## 감사 로그 확인

```bash
aws logs tail /aws/ssm/session-logs/prd --profile prd --region ap-northeast-2 --since 1h
```
세션 중 실행한 명령·출력이 기록된다. "누가 언제 blog에서 무엇을 했는지" 추적용.

## 비용

세션 로그는 터미널 텍스트라 월 수십 MB 수준 → 월 몇 센트. 사실상 무시 가능.

## 주의

- 세션 문서(`SSM-SessionManagerRunShell`)는 **계정 전역**이라, 로그그룹 설정 시 prd의 모든 SSM 세션이 같은 그룹에 로깅된다 (추가 기록일 뿐 기존 동작 영향 없음).
- 이 문서는 현재 콘솔에서 수동 관리됨. GitOps화하려면 별도 `ssm-session-config` 스택으로 import해 관리할 것.
