output "airflow_connection_bundle_secret_names" {
  description = "Airflow connection bundle Secrets Manager names"
  value       = { for key, secret in aws_secretsmanager_secret.airflow_connection_bundle : key => secret.name }
}

output "airflow_connection_bundle_secret_arns" {
  description = "Airflow connection bundle Secrets Manager ARNs"
  value       = { for key, secret in aws_secretsmanager_secret.airflow_connection_bundle : key => secret.arn }
}
