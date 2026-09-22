#!/usr/bin/env node
/**
 * ERP MSP사 AWS 청구서 자동화
 *
 * 플로우:
 * 1. 로그인
 * 2. MyPage → 회계 → 전자(세금)계산서 → MSP사 조회
 * 3. 매입전표 Ⅰ 생성 (부서 + 적요 입력)
 * 4. 회계거래조회 → 계정과목 설정 (지급수수료_기타 / 미지급금_국내)
 * 5. 전자결재 → 지출결의서 → 결재자 설정 → 상신
 *
 * 사용법:
 *   node erp-billing.js --billing-month 2 --payment-date 2026-03-31
 */

const { chromium } = require('playwright');

// ─── 설정 ────────────────────────────────────────────────────────────────────
const CONFIG = {
  url: 'https://erp.example',
  companyCode: '000000',
  // 1Password에서 런타임에 주입 (환경변수로 전달)
  userId: process.env.ERP_USER_ID || '0000000',
  password: process.env.ERP_PASSWORD,

  // 고정 설정 — 필요 시 수정
  department: process.env.ERP_DEPARTMENT || '',   // 예: '인프라팀'
  approver: process.env.ERP_APPROVER || '',        // 예: '홍길동'
  vendor: 'MSP사클라우드',

  headless: process.env.HEADLESS !== 'false',          // 디버깅 시 HEADLESS=false
  timeout: 30_000,
};
// ─────────────────────────────────────────────────────────────────────────────

function parseArgs() {
  const args = process.argv.slice(2);
  const result = {};
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i].replace(/^--/, '').replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    result[key] = args[i + 1];
  }
  return result;
}

async function run() {
  const { billingMonth, paymentDate } = parseArgs();

  if (!billingMonth || !paymentDate) {
    console.error('Usage: node erp-billing.js --billing-month <N> --payment-date <YYYY-MM-DD>');
    process.exit(1);
  }
  if (!CONFIG.password) {
    console.error('ERP_PASSWORD 환경변수가 설정되지 않았습니다.');
    process.exit(1);
  }
  if (!CONFIG.department) {
    console.error('ERP_DEPARTMENT 환경변수가 설정되지 않았습니다.');
    process.exit(1);
  }
  if (!CONFIG.approver) {
    console.error('ERP_APPROVER 환경변수가 설정되지 않았습니다.');
    process.exit(1);
  }

  const memo = `AWS 이용료 ${billingMonth}월분`;

  console.log(`▶ ERP 자동화 시작`);
  console.log(`  청구월: ${billingMonth}월 / 지급일: ${paymentDate} / 적요: ${memo}`);

  const browser = await chromium.launch({ headless: CONFIG.headless });
  const context = await browser.newContext({ viewport: { width: 1400, height: 900 } });
  const page = await context.newPage();
  page.setDefaultTimeout(CONFIG.timeout);

  try {
    // ── 1. 로그인 ─────────────────────────────────────────────────────────────
    console.log('▶ 로그인 중...');
    await page.goto(CONFIG.url);

    await page.fill('input[name="COM_CODE"], #COM_CODE', CONFIG.companyCode);
    await page.fill('input[name="USER_ID"], #USER_ID', CONFIG.userId);
    await page.fill('input[name="PW"], #PW', CONFIG.password);
    await page.click('button[type="submit"], input[type="submit"], #btnLogin');
    await page.waitForNavigation({ waitUntil: 'networkidle' });
    console.log('✅ 로그인 완료');

    // ── 2. MyPage → 회계 → 전자(세금)계산서 ─────────────────────────────────
    console.log('▶ 전자세금계산서 메뉴 이동...');
    // MyPage 클릭
    await page.click('text=MyPage, a[href*="mypage"], #mypage').catch(() =>
      page.click('text=MyPage')
    );
    await page.waitForLoadState('networkidle');

    // 회계 메뉴
    await page.click('text=회계').catch(() =>
      page.locator('nav >> text=회계').first().click()
    );

    // 전자(세금)계산서
    await page.click('text=전자(세금)계산서, text=전자세금계산서').catch(() =>
      page.locator('text=세금계산서').first().click()
    );
    await page.waitForLoadState('networkidle');
    console.log('✅ 전자세금계산서 화면 진입');

    // ── 3. MSP사 세금계산서 조회 ──────────────────────────────────────────────
    console.log(`▶ ${CONFIG.vendor} 세금계산서 조회...`);

    // 거래처 검색 필드에 MSP사클라우드 입력
    const vendorInput = page.locator('input[placeholder*="거래처"], input[name*="COMP"], #COMP_CD');
    await vendorInput.fill(CONFIG.vendor);
    await page.keyboard.press('F3');  // 조회
    await page.waitForLoadState('networkidle');

    // 청구월에 해당하는 세금계산서 찾기 (월 기준 필터)
    const monthStr = String(billingMonth).padStart(2, '0');
    const rows = page.locator(`tr:has-text("${monthStr}"):has-text("${CONFIG.vendor}")`);
    const rowCount = await rows.count();

    if (rowCount === 0) {
      throw new Error(`${billingMonth}월 ${CONFIG.vendor} 세금계산서를 찾을 수 없습니다.`);
    }

    // 첫 번째 매칭 행 선택 (체크박스)
    await rows.first().locator('input[type="checkbox"]').check();
    console.log(`✅ 세금계산서 선택 완료 (${rowCount}건 중 첫 번째)`);

    // ── 4. 매입전표 Ⅰ 생성 ────────────────────────────────────────────────────
    console.log('▶ 매입전표 Ⅰ 생성...');

    // ▲ 버튼 클릭 후 매입전표 Ⅰ 선택
    await page.click('button:has-text("▲"), .btn-up, [title="전표처리"]');
    await page.click('text=매입전표 Ⅰ, text=매입전표Ⅰ, text=매입전표1');
    await page.waitForLoadState('networkidle');

    // 부서 입력
    const deptInput = page.locator('input[placeholder*="부서"], input[name*="DEPT"], #DEPT_CD');
    await deptInput.fill(CONFIG.department);
    await page.keyboard.press('Tab');
    await page.waitForTimeout(500);

    // 팝업에서 부서 선택 (자동완성)
    const deptOption = page.locator(`.popup >> text=${CONFIG.department}`);
    if (await deptOption.isVisible({ timeout: 2000 }).catch(() => false)) {
      await deptOption.click();
    }

    // 적요 입력
    const memoInput = page.locator('input[placeholder*="적요"], input[name*="REMARK"], #REMARK');
    await memoInput.fill(memo);

    // F8 생성
    await page.keyboard.press('F8');
    await page.waitForLoadState('networkidle');
    console.log('✅ 매입전표 Ⅰ 생성 완료');

    // ── 5. 회계거래조회 → 계정과목 설정 ──────────────────────────────────────
    console.log('▶ 회계거래조회 → 계정과목 설정...');

    await page.click('text=회계분개, text=회계거래조회, button:has-text("회계거래")');
    await page.waitForLoadState('networkidle');

    // 방금 생성한 전표번호 클릭 (가장 최신 = 상단)
    await page.locator('table tr').nth(1).click();
    await page.waitForLoadState('networkidle');

    // 매입계정: 지급수수료_기타
    const debitInput = page.locator('input[placeholder*="매입계정"], input[name*="DEBIT"], #DEBIT_CD').first();
    await debitInput.fill('지급수수료');
    await page.keyboard.press('Tab');
    await page.waitForTimeout(500);
    const debitOption = page.locator('.popup >> text=지급수수료_기타');
    if (await debitOption.isVisible({ timeout: 2000 }).catch(() => false)) {
      await debitOption.click();
    }

    // 채무계정: 미지급금_국내
    const creditInput = page.locator('input[placeholder*="채무계정"], input[name*="CREDIT"], #CREDIT_CD').first();
    await creditInput.fill('미지급금');
    await page.keyboard.press('Tab');
    await page.waitForTimeout(500);
    const creditOption = page.locator('.popup >> text=미지급금_국내');
    if (await creditOption.isVisible({ timeout: 2000 }).catch(() => false)) {
      await creditOption.click();
    }

    // 저장
    await page.keyboard.press('F8');
    await page.waitForLoadState('networkidle');
    console.log('✅ 계정과목 설정 완료');

    // ── 6. 전자결재 → 지출결의서 상신 ────────────────────────────────────────
    console.log('▶ 전자결재 상신...');

    // 전자결재 버튼
    await page.locator('button:has-text("전자결재"), a:has-text("전자결재")').first().click();
    await page.waitForLoadState('networkidle');

    // 지출결의서 양식 선택
    await page.click('text=지출결의서');
    await page.waitForLoadState('networkidle');

    // 결재자 설정
    // 본인 아래 공란 더블클릭 → 결재자 검색
    const approverCell = page.locator('.approver-cell:empty, td.empty').first();
    await approverCell.dblclick();
    await page.waitForTimeout(500);

    const approverSearch = page.locator('input[placeholder*="결재자"], input[placeholder*="이름"], .approver-search input');
    await approverSearch.fill(CONFIG.approver);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(500);

    const approverOption = page.locator(`.popup >> text=${CONFIG.approver}`).first();
    if (await approverOption.isVisible({ timeout: 3000 }).catch(() => false)) {
      await approverOption.click();
    }

    // 본문 내용
    const bodyInput = page.locator('textarea[name*="CONTENT"], #CONTENT, textarea.content');
    await bodyInput.fill(
      `${billingMonth}월 AWS 이용료 지급 요청드립니다.\n거래처: ${CONFIG.vendor}\n지급예정일: ${paymentDate}\n적요: ${memo}`
    );

    // 저장/결재 F7
    await page.keyboard.press('F7');
    await page.waitForLoadState('networkidle');

    console.log('✅ 전자결재 상신 완료!');
    console.log(`  지급일자: ${paymentDate}`);

    // 결과 JSON 출력 (n8n이 파싱)
    const result = {
      success: true,
      billingMonth: parseInt(billingMonth),
      paymentDate,
      memo,
      vendor: CONFIG.vendor,
    };
    process.stdout.write('\n__RESULT__' + JSON.stringify(result) + '\n');

  } catch (err) {
    // 디버깅용 스크린샷
    await page.screenshot({ path: `/tmp/erp-error-${Date.now()}.png` });
    console.error(`❌ 오류: ${err.message}`);
    const result = { success: false, error: err.message };
    process.stdout.write('\n__RESULT__' + JSON.stringify(result) + '\n');
    process.exit(1);
  } finally {
    await browser.close();
  }
}

run();
