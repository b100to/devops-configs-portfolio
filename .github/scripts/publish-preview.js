// Posts (or updates) a single sticky comment per environment holding the
// Terraform plan for this PR, and flags the case where the PR was already
// merged before the preview finished.
const fs = require('fs')

const COMMENT_LIMIT = 55000

module.exports = async ({ github, context, core }) => {
  const env = process.env.TM_ENV
  const marker = `<!-- terramate-preview-${env} -->`
  const stacks = (process.env.TM_STACKS || '').trim()

  let body = `${marker}\n### 🔍 Terraform Preview — \`${env}\`\n\n`

  if (!stacks) {
    body += `변경된 \`${env}\` 스택 없음.\n`
  } else {
    let plan
    try {
      plan = fs.readFileSync(`/tmp/plan-${env}.txt`, 'utf8')
    } catch (err) {
      plan = `(plan 출력을 읽지 못함: ${err.message})`
    }
    if (plan.length > COMMENT_LIMIT) {
      plan = `...(앞부분 ${plan.length - COMMENT_LIMIT}자 생략, 전체는 Actions 로그 참고)...\n` +
        plan.slice(-COMMENT_LIMIT)
    }
    body += '변경된 스택:\n```\n' + stacks + '\n```\n\n' +
      '<details><summary>terraform plan</summary>\n\n```hcl\n' + plan + '\n```\n\n</details>\n'
  }

  const { data: pr } = await github.rest.pulls.get({
    ...context.repo,
    pull_number: context.issue.number,
  })

  if (pr.merged) {
    body += '\n> ⚠️ **이 PR은 preview가 끝나기 전에 머지되었습니다** (auto-merge race).\n' +
      '> 위 plan은 사후 기록이며, 머지 전 검토 용도로 쓰이지 못했습니다.\n' +
      '> 머지 전에 plan을 보려면 `main` 브랜치 보호에 `Plan (dev)` / `Plan (prd)`를 required status check로 등록하세요.\n'
    core.warning(`PR #${context.issue.number} was merged before the ${env} preview finished.`)
  }

  await core.summary
    .addHeading(`Terraform Preview — ${env}`, 3)
    .addRaw(stacks ? `변경된 스택:\n\n\`\`\`\n${stacks}\n\`\`\`` : `변경된 \`${env}\` 스택 없음.`)
    .write()

  const comments = await github.paginate(github.rest.issues.listComments, {
    ...context.repo,
    issue_number: context.issue.number,
    per_page: 100,
  })
  const existing = comments.find((c) => c.body && c.body.includes(marker))

  if (existing) {
    await github.rest.issues.updateComment({
      ...context.repo,
      comment_id: existing.id,
      body,
    })
  } else {
    await github.rest.issues.createComment({
      ...context.repo,
      issue_number: context.issue.number,
      body,
    })
  }
}
