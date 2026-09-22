generate_hcl "_terramate_generated_locals.tf" {
  content {
    locals {
      monitor_name = "[${upper(var.environment)}] OOMKilled 감지"

      # system_probe eBPF 기반 OOM kill 이벤트 카운터.
      # oom_kill.oom_process.count 는 커널 cgroup OOM killer 발생 시점에 한 번만
      # 카운트되는 이벤트 메트릭 — 새 파드/CrashLoopBackOff 모두 발생 즉시 감지 가능.
      # (이전 방식인 kubernetes.containers.last_state.terminated 는 OOM 상태 지속 중
      # 계속 리포팅되어 change() 없이는 알림 반복, change() 사용 시 신규 파드 첫 OOM 누락)
      # pod_name 은 restartPolicy:Never 파드에서 N/A 로 수집되고,
      # Datadog 멀티얼럿이 N/A 그룹을 평가 대상에서 제외하므로 pod_name 제외.
      pod_restart_query = format(
        "sum(last_%dm):sum:oom_kill.oom_process.count{cluster_name:%s} by {kube_namespace,kube_container_name}.as_count() > %d",
        var.monitor_evaluation_window_min,
        var.cluster_name,
        var.monitor_restart_threshold,
      )

      # Slack handle: workspace prefix 생략 시 `@slack-<channel>` 형태 사용
      # Datadog 에 workspace 가 단일 또는 alias 가 여러 개 있는 경우 workspace
      # 이름을 붙이면 stale alias 로 라우팅되어 메시지가 drop 될 수 있음
      # (실측: @slack-Acme-alert-prd 는 "sent" 로 기록되지만 도달 안 함,
      #        @slack-alert-prd 는 정상 도달)
      slack_handle = var.slack_account_name == "" ? format(
        "@slack-%s",
        trimprefix(var.slack_channel_name, "#"),
        ) : format(
        "@slack-%s-%s",
        var.slack_account_name,
        trimprefix(var.slack_channel_name, "#"),
      )

      # 최소 메시지: 제목이 이미 "Triggered: [PRD] 파드 재시작" 로 명시되므로
      # 본문은 어느 pod 인지만 보여주면 충분. Recovery 블록은 제거해 알림 최소화
      # (Datadog 은 상태 전환 시 Recovery 알림을 기본 발송하지만 body 가 비어
      # 제목 한 줄만 오는 수준으로 영향 최소화).
      monitor_message = <<-EOT
        {{#is_alert}}
        :oom: *OOMKilled*
        *Namespace:* `{{kube_namespace.name}}`
        *Container:* `{{kube_container_name.name}}`
        {{/is_alert}}

        ${local.slack_handle}
      EOT

      monitor_tags = concat(
        [
          "env:${var.environment}",
          "cluster:${var.cluster_name}",
          "managed_by:terraform",
          "source:devops-configs",
        ],
        var.notification_tags,
      )
    }
  }
}
