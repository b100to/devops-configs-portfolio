generate_hcl "_terramate_generated_outputs.tf" {
  content {
    output "dashboard_url" {
      description = "Datadog Airflow 대시보드 URL"
      value       = "https://app.${var.datadog_site}/dashboard/${datadog_dashboard.airflow.id}"
    }
  }
}
