locals {
  airflow_connection_bundles = {
    core = {
      description = "Airflow connection bundle for shared/core connections"
      replacement_for = [
        "airflow/connections/gcp_conn_1",
        "airflow/connections/aws_conn_1",
        "airflow/connections/slack_conn_1",
      ]
    }
    mall = {
      description = "Airflow connection bundle for mall connections"
      replacement_for = [
        "airflow/connections/mall_conn_1",
        "airflow/connections/mall_live_conn_1",
        "airflow/connections/service_conn_1",
      ]
    }
    partner1 = {
      description = "Airflow connection bundle for PARTNER1 connections"
      replacement_for = [
        "airflow/connections/partner1_conn_1",
        "airflow/connections/partner1_live_conn_1",
        "airflow/connections/partner1_conn_migration_1",
        "airflow/connections/partner1_conn_live_migration_1",
        "airflow/connections/partner1_conn_chunk",
        "airflow/connections/aws_conn_partner1_1",
      ]
    }
    recommendation = {
      description = "Airflow connection bundle for recommendation connections"
      replacement_for = [
        "airflow/connections/recommendation_conn_1",
      ]
    }
  }
}

resource "aws_secretsmanager_secret" "airflow_connection_bundle" {
  for_each = local.airflow_connection_bundles

  name        = "airflow/connections/${each.key}"
  description = each.value.description

  recovery_window_in_days = 7

  tags = {
    Name        = "airflow/connections/${each.key}"
    Service     = "airflow"
    Environment = "prd"
    ManagedBy   = "terraform"
    SecretClass = "airflow-connection-bundle"
    Rotation    = "manual"
  }
}
