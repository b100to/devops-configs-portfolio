---
name: slack
description: 작업 완료 내용을 Slack #team-devops 채널에 공유. 대화 컨텍스트와 커밋을 요약하여 전송.
invocation:
  - /slack
  - 슬랙 공유
  - 슬랙에 올려
  - slack
---

# Slack 작업 공유 Skill

작업 완료 내용을 요약하여 Slack Incoming Webhook으로 전송합니다.

## 설정

Webhook URL은 아래 파일에 저장:

```
~/.Codex/skills/slack/config.env
```

```bash
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/XXXXX/XXXXX/XXXXX
```

> Webhook URL이 설정되지 않았으면 사용자에게 안내하고 중단

## Workflow

### 1. Webhook URL 로드

```bash
source ~/.Codex/skills/slack/config.env
```

URL이 비어있거나 파일이 없으면:
- "Webhook URL이 설정되지 않았습니다. `~/.Codex/skills/slack/config.env`에 SLACK_WEBHOOK_URL을 설정해주세요." 출력 후 중단

### 2. 작업 내용 수집

현재 대화 컨텍스트에서 수집:
- 이번 세션에서 수행한 작업 요약
- 관련 커밋 (있으면)
- 변경된 주요 파일/서비스
- 관련 GitHub 이슈 번호 (있으면)

```bash
# 최근 커밋 확인 (오늘, 이 브랜치)
git log --since="$(date +%Y-%m-%d)T00:00:00" --oneline -10
```

### 3. 메시지 작성

Slack Block Kit 형식으로 구성:

```json
{
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "{작업 제목}"
      }
    },
    {
      "type": "section",
      "fields": [
        { "type": "mrkdwn", "text": "*환경:*\n{dev/prd}" },
        { "type": "mrkdwn", "text": "*브랜치:*\n{branch}" }
      ]
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "{작업 내용 요약 (bullet points)}"
      }
    },
    {
      "type": "context",
      "elements": [
        { "type": "mrkdwn", "text": "{관련 커밋 해시} | {이슈 링크}" }
      ]
    }
  ]
}
```

### 4. 전송

```bash
curl -s -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD"
```

### 5. 결과 확인

- HTTP 200 + "ok" → 전송 성공
- 그 외 → 에러 메시지 출력

## 메시지 작성 규칙

- 한국어로 작성
- 제목: 핵심 작업 한 줄 요약 (20자 이내)
- 본문: 3~5개 bullet point로 간결하게
- 보안 민감 정보 제외 (시크릿, 토큰, 비밀번호, AWS 계정 ID 등)
- 커밋 해시는 short hash (7자)
- 이슈가 있으면 `#이슈번호` 형태로 링크

## 메시지 예시

```
📋 EKS v2 인프라 서비스 IP 접근 제한 적용

환경: dev, prd
브랜치: feature/eks-v2

• ArgoCD, Grafana, Kafka UI 등 6개 인프라 서비스에 사내 IP 접근 제한 적용
• dev 환경 먼저 적용 후 검증 완료
• prd 환경 적용 및 싱크 확인 완료

b3fa7c9, a63b630 | #68
```

## Example Usage

**사용자**: `/slack` 또는 "슬랙에 공유해줘"

**Codex**:
1. config.env에서 Webhook URL 로드
2. 대화 컨텍스트 + 커밋에서 작업 내용 수집
3. Block Kit 메시지 구성
4. curl로 Webhook 전송
5. 결과 출력
