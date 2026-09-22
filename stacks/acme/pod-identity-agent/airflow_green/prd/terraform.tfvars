service_account = "airflow-green"
namespace       = "airflow-green"

service_accounts = [
  "airflow-green-api-server-sa",
  "airflow-green-cleanup-sa",
  "airflow-green-create-user-job-sa",
  "airflow-green-dag-processor-sa",
  "airflow-green-migrate-database-job-sa",
  "airflow-green-scheduler-sa",
  "airflow-green-triggerer-sa",
  "airflow-green-worker",
]
