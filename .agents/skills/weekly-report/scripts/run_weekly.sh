#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/works/devops-configs"
LOG_DIR="$HOME/Library/Logs/weekly-report"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/$(date +%Y-%m-%d).log"

export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

cd "$REPO"

PROMPT='/weekly-report

이번 주(이번 주 월요일부터 오늘까지) 주간 보고서를 자동으로 생성하고 시트에 등록까지 진행해. 사용자 확인/검토 단계는 건너뛰고 다음을 수행:
1. git 커밋과 ~/.claude/sessions/devops-configs/ 세션 기록 수집
2. 상세본을 docs/logs/weekly/{YYYY-MM}-{N}W.md 로 저장
3. 압축본을 docs/logs/weekly/{YYYY-MM}-{N}W-summary.md 로 저장 (# 카테고리 + - 항목 형식, 시트 파서 호환)
4. uv 로 export_to_sheets.py 실행: SPREADSHEET_ID=your-spreadsheet-id, 워크시트=Alex
5. 완료 후 결과 한 줄 요약 출력'

echo "[$(date)] weekly-report run start" >> "$LOG"
claude -p "$PROMPT" \
  --dangerously-skip-permissions \
  --add-dir "$REPO" \
  >> "$LOG" 2>&1
echo "[$(date)] weekly-report run end (exit=$?)" >> "$LOG"
