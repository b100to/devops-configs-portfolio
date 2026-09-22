#!/usr/bin/env python3
"""주간 보고서 마크다운을 파싱하여 Google Sheets에 등록하는 스크립트.

Google Sheets API를 사용하여 대상 시트의 특정 셀만 수정합니다.
(openpyxl load→save 방식과 달리 다른 시트에 영향을 주지 않음)
"""

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build

SCOPES = ["https://www.googleapis.com/auth/spreadsheets"]
DEFAULT_CREDENTIALS_PATH = Path(__file__).parent.parent / "references" / "service-account.json"
DEFAULT_WORKSHEET = "Alex"
FONT_FAMILY = "Noto Sans KR"
FONT_SIZE = 10
CELL_PADDING = {"top": 8, "bottom": 8, "left": 8, "right": 8}


# ---------------------------------------------------------------------------
# 마크다운 파싱
# ---------------------------------------------------------------------------

def parse_report(filepath: str) -> dict:
    """마크다운 보고서를 파싱하여 구조화된 데이터로 변환."""
    text = Path(filepath).read_text(encoding="utf-8")
    lines = text.splitlines()

    period = ""
    categories: list[dict] = []
    next_week_items: list[str] = []
    current_category = None
    in_next_week = False

    for line in lines:
        if line.startswith("**기간**:"):
            period = line.replace("**기간**:", "").strip()
            continue
        if line.startswith("---") or line.startswith("**작성일**"):
            continue
        if line.startswith("# ") and not line.startswith("# 주간"):
            header = line[2:].strip()
            if header == "차주 예정":
                in_next_week = True
                current_category = None
                continue
            in_next_week = False
            current_category = {"name": header, "items": []}
            categories.append(current_category)
            continue

        stripped = line.strip()
        if not stripped:
            continue
        if in_next_week and (stripped.startswith("- ") or stripped.startswith("-> ")):
            next_week_items.append(stripped)
        elif current_category is not None and (stripped.startswith("- ") or stripped.startswith("-> ")):
            current_category["items"].append(stripped)

    return {
        "period": period,
        "categories": categories,
        "next_week": next_week_items,
    }


def period_to_week_label(period: str) -> str:
    """기간 문자열을 주차 라벨로 변환 (예: '2026-01-26 (월) ~ 2026-01-29 (목)' → '2026-01-4W')."""
    match = re.search(r"(\d{4})-(\d{2})-(\d{2})", period)
    if not match:
        return period
    year, month, day = int(match.group(1)), int(match.group(2)), int(match.group(3))
    start_date = datetime(year, month, day)
    first_day = datetime(year, month, 1)
    days_until_monday = (7 - first_day.weekday()) % 7
    first_monday = first_day.replace(day=1 + days_until_monday)
    if first_monday.month != month:
        first_monday = first_day
    week_num = ((start_date - first_monday).days // 7) + 1
    if week_num < 1:
        week_num = 1
    return f"{year}-{month:02d} {week_num}W"


def _indent_item(item: str) -> str:
    """항목 들여쓰기: '- '는 2칸, '-> '는 4칸."""
    if item.startswith("-> "):
        return f"    {item}"
    return f"  {item}"


def build_weekly_content(categories: list[dict]) -> str:
    """카테고리별 항목을 하나의 셀 텍스트로 합침 (plain text 버전, dry-run용)."""
    parts = []
    for cat in categories:
        parts.append(f"[{cat['name']}]")
        for item in cat["items"]:
            parts.append(_indent_item(item))
        parts.append("")
    while parts and parts[-1] == "":
        parts.pop()
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Google Sheets API 헬퍼
# ---------------------------------------------------------------------------

def _build_rich_content(categories: list[dict]) -> tuple[str, list[dict]]:
    """카테고리별 항목을 텍스트 + textFormatRuns으로 변환."""
    text_parts: list[str] = []
    runs: list[dict] = []

    for i, cat in enumerate(categories):
        if i > 0:
            text_parts.append("\n\n")

        # 카테고리명 (볼드)
        start = sum(len(p) for p in text_parts)
        cat_text = f"[{cat['name']}]"
        text_parts.append(cat_text)
        runs.append({
            "startIndex": start,
            "format": {"bold": True, "fontFamily": FONT_FAMILY, "fontSize": FONT_SIZE},
        })

        # 항목들 (일반)
        items_text = ""
        for item in cat["items"]:
            items_text += f"\n{_indent_item(item)}"
        if items_text:
            start = sum(len(p) for p in text_parts)
            text_parts.append(items_text)
            runs.append({
                "startIndex": start,
                "format": {"bold": False, "fontFamily": FONT_FAMILY, "fontSize": FONT_SIZE},
            })

    return "".join(text_parts), runs


def _thin_border():
    """전체 얇은 테두리."""
    side = {"style": "SOLID", "colorStyle": {"rgbColor": {"red": 0, "green": 0, "blue": 0}}}
    return {"top": side, "bottom": side, "left": side, "right": side}


def _fmt_center():
    """A열: 가운데 정렬."""
    return {
        "horizontalAlignment": "CENTER",
        "verticalAlignment": "MIDDLE",
        "wrapStrategy": "WRAP",
        "textFormat": {"fontFamily": FONT_FAMILY, "fontSize": FONT_SIZE},
        "borders": _thin_border(),
        "padding": CELL_PADDING,
    }


def _fmt_left():
    """B~D열: 왼쪽 정렬."""
    return {
        "horizontalAlignment": "LEFT",
        "verticalAlignment": "MIDDLE",
        "wrapStrategy": "WRAP",
        "textFormat": {"fontFamily": FONT_FAMILY, "fontSize": FONT_SIZE},
        "borders": _thin_border(),
        "padding": CELL_PADDING,
    }


def get_sheet_id(service, spreadsheet_id: str, sheet_name: str) -> int:
    """시트 이름으로 sheetId 조회."""
    meta = service.spreadsheets().get(spreadsheetId=spreadsheet_id).execute()
    for sheet in meta["sheets"]:
        if sheet["properties"]["title"] == sheet_name:
            return sheet["properties"]["sheetId"]
    raise ValueError(f"시트 '{sheet_name}'을 찾을 수 없습니다")


def _parse_week_label(label: str) -> tuple[int, int, int] | None:
    """주차 라벨을 정렬 가능한 튜플로 변환 (예: '2026-01 4W' → (2026, 1, 4))."""
    m = re.match(r"(\d{4})-(\d{2})\s+(\d+)W", str(label).strip())
    if m:
        return (int(m.group(1)), int(m.group(2)), int(m.group(3)))
    return None


def find_existing_row(service, spreadsheet_id: str, sheet_name: str, week_label: str) -> int | None:
    """A열에서 같은 주차 라벨이 있는 행 인덱스를 찾음 (0-based). 없으면 None."""
    result = service.spreadsheets().values().get(
        spreadsheetId=spreadsheet_id,
        range=f"'{sheet_name}'!A:A",
    ).execute()
    values = result.get("values", [])
    for i, row in enumerate(values):
        if row and str(row[0]).strip() == week_label:
            return i
    return None


def find_insert_position(service, spreadsheet_id: str, sheet_name: str, week_label: str) -> int:
    """새 주차를 삽입할 위치를 찾음 (0-based). 최신이 위, 과거가 아래."""
    result = service.spreadsheets().values().get(
        spreadsheetId=spreadsheet_id,
        range=f"'{sheet_name}'!A:A",
    ).execute()
    values = result.get("values", [])
    new_key = _parse_week_label(week_label)
    if not new_key:
        return 1  # 파싱 실패 시 header 바로 아래

    # 행 1(header) 이후부터 탐색 (내림차순: 최신이 위)
    for i in range(1, len(values)):
        if not values[i]:
            continue
        existing_key = _parse_week_label(values[i][0])
        if existing_key is None:
            # NW 형식이 아닌 행 = 기존 데이터 → 그 앞에 삽입
            return i
        if existing_key < new_key:
            # 더 오래된 주차 → 그 앞에 삽입
            return i
    # 모든 기존 행이 더 최신이면 맨 아래
    return len(values)


# ---------------------------------------------------------------------------
# 메인 등록 로직
# ---------------------------------------------------------------------------

def export_to_sheets(
    report: dict,
    spreadsheet_id: str,
    worksheet_name: str | None = None,
    credentials_path: str | None = None,
):
    """파싱된 보고서를 Google Sheets에 등록."""
    creds_path = Path(credentials_path) if credentials_path else DEFAULT_CREDENTIALS_PATH
    if not creds_path.exists():
        print(f"Error: 서비스 계정 키 파일을 찾을 수 없습니다: {creds_path}", file=sys.stderr)
        sys.exit(1)

    creds = Credentials.from_service_account_file(str(creds_path), scopes=SCOPES)
    service = build("sheets", "v4", credentials=creds)

    ws_name = worksheet_name or DEFAULT_WORKSHEET
    sheet_id = get_sheet_id(service, spreadsheet_id, ws_name)

    # 데이터 준비
    week_label = period_to_week_label(report["period"])
    rich_text, text_runs = _build_rich_content(report["categories"])
    next_week_text = "\n".join(report["next_week"]) if report["next_week"] else ""

    # 같은 주차 행 탐색
    existing_row_idx = find_existing_row(service, spreadsheet_id, ws_name, week_label)

    requests = []

    if existing_row_idx is not None:
        target_row = existing_row_idx  # 0-based
        action = "업데이트"
    else:
        target_row = find_insert_position(service, spreadsheet_id, ws_name, week_label)
        action = "삽입"
        requests.append({
            "insertDimension": {
                "range": {
                    "sheetId": sheet_id,
                    "dimension": "ROWS",
                    "startIndex": target_row,
                    "endIndex": target_row + 1,
                },
                "inheritFromBefore": False,
            }
        })

    # 셀 데이터 구성 (A~D: 주차, 금주 업무, 차주 예정, 특이 사항)
    # Note: textFormatRuns는 별도 요청으로 분리 (userEnteredValue와 충돌 방지)
    row_data = {
        "values": [
            # A: 주차
            {
                "userEnteredValue": {"stringValue": week_label},
                "userEnteredFormat": _fmt_center(),
            },
            # B: 금주 업무 (일단 plain text로 설정, 포맷은 별도 요청)
            {
                "userEnteredValue": {"stringValue": rich_text},
                "userEnteredFormat": _fmt_left(),
            },
            # C: 차주 예정
            {
                "userEnteredValue": {"stringValue": next_week_text},
                "userEnteredFormat": _fmt_left(),
            },
            # D: 특이 사항 (수동 입력용)
            {
                "userEnteredValue": {"stringValue": ""},
                "userEnteredFormat": _fmt_left(),
            },
        ]
    }

    requests.append({
        "updateCells": {
            "rows": [row_data],
            "fields": "userEnteredValue,userEnteredFormat",
            "start": {
                "sheetId": sheet_id,
                "rowIndex": target_row,
                "columnIndex": 0,
            },
        }
    })

    # B열에 textFormatRuns 별도 적용 (볼드 처리)
    if text_runs:
        requests.append({
            "updateCells": {
                "rows": [{
                    "values": [{
                        "textFormatRuns": text_runs,
                    }]
                }],
                "fields": "textFormatRuns",
                "start": {
                    "sheetId": sheet_id,
                    "rowIndex": target_row,
                    "columnIndex": 1,  # B열
                },
            }
        })

    # 행 높이 자동 조절
    requests.append({
        "autoResizeDimensions": {
            "dimensions": {
                "sheetId": sheet_id,
                "dimension": "ROWS",
                "startIndex": target_row,
                "endIndex": target_row + 1,
            }
        }
    })

    service.spreadsheets().batchUpdate(
        spreadsheetId=spreadsheet_id,
        body={"requests": requests},
    ).execute()

    print(f"'{ws_name}' 시트 행 {target_row + 1} {action} 완료")
    print(f"  주차: {week_label}")
    print(f"  금주: {len(report['categories'])}개 카테고리")
    print(f"  차주: {len(report['next_week'])}개 항목")


def main():
    parser = argparse.ArgumentParser(description="주간 보고서를 Google Sheets에 등록")
    parser.add_argument("--file", "-f", required=True, help="보고서 마크다운 파일 경로")
    parser.add_argument("--sheet-id", "-s", required=True, help="Google Spreadsheet ID")
    parser.add_argument("--worksheet", "-w", default=None, help=f"워크시트 이름 (기본: {DEFAULT_WORKSHEET})")
    parser.add_argument("--credentials", "-c", default=None, help="서비스 계정 JSON 키 경로")
    parser.add_argument("--dry-run", action="store_true", help="파싱 결과만 출력 (시트에 쓰지 않음)")
    args = parser.parse_args()

    report = parse_report(args.file)

    if args.dry_run:
        week_label = period_to_week_label(report["period"])
        print(f"주차: {week_label}")
        print(f"금주 업무:")
        print(build_weekly_content(report["categories"]))
        if report["next_week"]:
            print(f"\n차주 예정:")
            for item in report["next_week"]:
                print(f"  {item}")
        return

    export_to_sheets(
        report=report,
        spreadsheet_id=args.sheet_id,
        worksheet_name=args.worksheet,
        credentials_path=args.credentials,
    )


if __name__ == "__main__":
    main()
