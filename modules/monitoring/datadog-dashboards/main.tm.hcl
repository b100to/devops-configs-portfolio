generate_hcl "_terramate_generated_main.tf" {
  content {
    data "aws_secretsmanager_secret_version" "datadog" {
      secret_id = var.datadog_secret_name
    }

    provider "datadog" {
      api_key = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["DD_API_KEY"]
      app_key = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["DD_APP_KEY"]
      api_url = "https://api.${var.datadog_site}/"
    }

    resource "datadog_dashboard" "airflow" {
      title       = "[${upper(var.environment)}] Airflow 모니터링"
      description = "Airflow-Green 운영 대시보드 — 노드/파드 리소스 + Airflow DogStatsD 메트릭 + 로그"
      layout_type = "ordered"

      # ─── 상태 요약 ────────────────────────────────────────────────────────
      widget {
        group_definition {
          title       = "📊 상태 요약"
          layout_type = "ordered"
          show_title  = true

          widget {
            query_value_definition {
              title     = "DAG 파싱 에러"
              autoscale = true
              precision = 0
              request {
                q          = "sum:airflow.dag_processing.import_errors{cluster_name:${var.cluster_name}}"
                aggregator = "last"
              }
              timeseries_background {
                type = "area"
              }
            }
          }

          widget {
            query_value_definition {
              title     = "실행 중 태스크"
              autoscale = true
              precision = 0
              request {
                q          = "avg:airflow.scheduler.tasks.running{cluster_name:${var.cluster_name}}"
                aggregator = "last"
              }
              timeseries_background {
                type = "area"
              }
            }
          }

          widget {
            query_value_definition {
              title     = "대기 중 태스크 (Starving)"
              autoscale = true
              precision = 0
              request {
                q          = "avg:airflow.scheduler.tasks.starving{cluster_name:${var.cluster_name}}"
                aggregator = "last"
              }
              timeseries_background {
                type = "area"
              }
            }
          }
        }
      }

      # ─── 노드 리소스 ──────────────────────────────────────────────────────
      widget {
        group_definition {
          title       = "🖥️ 노드 리소스 (airflow NodePool)"
          layout_type = "ordered"
          show_title  = true

          widget {
            timeseries_definition {
              title       = "노드 CPU 사용률 (%)"
              show_legend = true

              request {
                q            = "avg:system.cpu.user{karpenter_nodepool:airflow,env:${var.environment}} by {host}"
                display_type = "line"
                style {
                  palette    = "cool"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }

              request {
                q            = "avg:system.cpu.system{karpenter_nodepool:airflow,env:${var.environment}} by {host}"
                display_type = "line"
                style {
                  palette    = "warm"
                  line_type  = "solid"
                  line_width = "thin"
                }
              }

              yaxis {
                min          = "0"
                max          = "100"
                include_zero = true
              }
            }
          }

          widget {
            timeseries_definition {
              title       = "노드 메모리 사용량 (GB)"
              show_legend = true

              request {
                q            = "avg:system.mem.used{karpenter_nodepool:airflow,env:${var.environment}} by {host} / 1073741824"
                display_type = "area"
                style {
                  palette    = "purple"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }

              request {
                q            = "avg:system.mem.total{karpenter_nodepool:airflow,env:${var.environment}} by {host} / 1073741824"
                display_type = "line"
                style {
                  palette    = "grey"
                  line_type  = "dashed"
                  line_width = "normal"
                }
              }
            }
          }
        }
      }

      # ─── Pod 리소스 ──────────────────────────────────────────────────────
      widget {
        group_definition {
          title       = "🐳 Pod 리소스 (airflow-green)"
          layout_type = "ordered"
          show_title  = true

          widget {
            timeseries_definition {
              title       = "Pod CPU 사용량 (cores)"
              show_legend = true

              request {
                # kubernetes.cpu.usage.total 단위: nanocores → /1e9 = cores
                q            = "avg:kubernetes.cpu.usage.total{kube_namespace:airflow-green,cluster_name:${var.cluster_name}} by {pod_name} / 1000000000"
                display_type = "line"
                style {
                  palette    = "dog_classic"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }
            }
          }

          widget {
            timeseries_definition {
              title       = "Pod 메모리 사용량 (MB)"
              show_legend = true

              request {
                # kubernetes.memory.working_set 단위: bytes → /1048576 = MB
                q            = "avg:kubernetes.memory.working_set{kube_namespace:airflow-green,cluster_name:${var.cluster_name}} by {pod_name} / 1048576"
                display_type = "area"
                style {
                  palette    = "purple"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }
            }
          }
        }
      }

      # ─── 스케줄러 ─────────────────────────────────────────────────────────
      widget {
        group_definition {
          title       = "⚙️ 스케줄러"
          layout_type = "ordered"
          show_title  = true

          widget {
            timeseries_definition {
              title       = "Scheduler Heartbeat (beat/min)"
              show_legend = false

              request {
                q            = "sum:airflow.scheduler.heartbeat{cluster_name:${var.cluster_name}}"
                display_type = "bars"
                style {
                  palette    = "green"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }
            }
          }

          widget {
            timeseries_definition {
              title       = "DAG 파싱 시간 (초)"
              show_legend = false

              request {
                q            = "avg:airflow.dag_processing.total_parse_time{cluster_name:${var.cluster_name}}"
                display_type = "line"
                style {
                  palette    = "orange"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }
            }
          }
        }
      }

      # ─── 태스크 & 풀 ──────────────────────────────────────────────────────
      widget {
        group_definition {
          title       = "📋 태스크 & 풀"
          layout_type = "ordered"
          show_title  = true

          widget {
            timeseries_definition {
              title       = "태스크 상태 (Running / Starving / Killed)"
              show_legend = true

              request {
                q            = "avg:airflow.scheduler.tasks.running{cluster_name:${var.cluster_name}}"
                display_type = "line"
                style {
                  palette    = "green"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }

              request {
                q            = "avg:airflow.scheduler.tasks.starving{cluster_name:${var.cluster_name}}"
                display_type = "line"
                style {
                  palette    = "orange"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }

              request {
                q            = "sum:airflow.scheduler.tasks.killed_externally{cluster_name:${var.cluster_name}}"
                display_type = "bars"
                style {
                  palette    = "red"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }
            }
          }

          widget {
            timeseries_definition {
              title       = "풀 슬롯 by pool"
              show_legend = true

              request {
                q            = "avg:airflow.pool.running_slots{cluster_name:${var.cluster_name}} by {pool_name}"
                display_type = "area"
                style {
                  palette    = "green"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }

              request {
                q            = "avg:airflow.pool.queued_slots{cluster_name:${var.cluster_name}} by {pool_name}"
                display_type = "area"
                style {
                  palette    = "orange"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }

              request {
                q            = "avg:airflow.pool.open_slots{cluster_name:${var.cluster_name}} by {pool_name}"
                display_type = "line"
                style {
                  palette    = "grey"
                  line_type  = "dashed"
                  line_width = "normal"
                }
              }
            }
          }
        }
      }

      # ─── DAG Run ─────────────────────────────────────────────────────────
      widget {
        group_definition {
          title       = "🔄 DAG Run"
          layout_type = "ordered"
          show_title  = true

          widget {
            timeseries_definition {
              title       = "DAG Run 지속시간 (초) — Success vs Failed"
              show_legend = true

              request {
                q            = "avg:airflow.dagrun.duration.success{cluster_name:${var.cluster_name}} by {dag_id}"
                display_type = "line"
                style {
                  palette    = "green"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }

              request {
                q            = "avg:airflow.dagrun.duration.failed{cluster_name:${var.cluster_name}} by {dag_id}"
                display_type = "bars"
                style {
                  palette    = "red"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }
            }
          }

          widget {
            timeseries_definition {
              title       = "DAG Run 스케줄 지연 (초)"
              show_legend = true

              request {
                q            = "avg:airflow.dagrun.schedule_delay{cluster_name:${var.cluster_name}} by {dag_id}"
                display_type = "line"
                style {
                  palette    = "orange"
                  line_type  = "solid"
                  line_width = "normal"
                }
              }
            }
          }
        }
      }

      # ─── 로그 ────────────────────────────────────────────────────────────
      widget {
        log_stream_definition {
          title               = "📝 Airflow 로그"
          query               = "kube_namespace:airflow-green OR kube_namespace:airflow"
          columns             = ["core_host", "core_service", "core_status"]
          show_date_column    = true
          show_message_column = true
          message_display     = "expanded-md"

          sort {
            column = "time"
            order  = "desc"
          }
        }
      }
    }
  }
}
