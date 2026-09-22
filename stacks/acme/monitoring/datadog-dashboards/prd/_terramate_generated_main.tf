// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

data "aws_secretsmanager_secret_version" "datadog" {
  secret_id = var.datadog_secret_name
}
provider "datadog" {
  api_key = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["DD_API_KEY"]
  api_url = "https://api.${var.datadog_site}/"
  app_key = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["DD_APP_KEY"]
}
resource "datadog_dashboard" "airflow" {
  description = "Airflow-Green 운영 대시보드 — 노드/파드 리소스 + Airflow DogStatsD 메트릭 + 로그"
  layout_type = "ordered"
  title       = "[${upper(var.environment)}] Airflow 모니터링"
  widget {
    group_definition {
      layout_type = "ordered"
      show_title  = true
      title       = "📊 상태 요약"
      widget {
        query_value_definition {
          autoscale = true
          precision = 0
          title     = "DAG 파싱 에러"
          request {
            aggregator = "last"
            q          = "sum:airflow.dag_processing.import_errors{cluster_name:${var.cluster_name}}"
          }
          timeseries_background {
            type = "area"
          }
        }
      }
      widget {
        query_value_definition {
          autoscale = true
          precision = 0
          title     = "실행 중 태스크"
          request {
            aggregator = "last"
            q          = "avg:airflow.scheduler.tasks.running{cluster_name:${var.cluster_name}}"
          }
          timeseries_background {
            type = "area"
          }
        }
      }
      widget {
        query_value_definition {
          autoscale = true
          precision = 0
          title     = "대기 중 태스크 (Starving)"
          request {
            aggregator = "last"
            q          = "avg:airflow.scheduler.tasks.starving{cluster_name:${var.cluster_name}}"
          }
          timeseries_background {
            type = "area"
          }
        }
      }
    }
  }
  widget {
    group_definition {
      layout_type = "ordered"
      show_title  = true
      title       = "🖥️ 노드 리소스 (airflow NodePool)"
      widget {
        timeseries_definition {
          show_legend = true
          title       = "노드 CPU 사용률 (%)"
          request {
            display_type = "line"
            q            = "avg:system.cpu.user{karpenter_nodepool:airflow,env:${var.environment}} by {host}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "cool"
            }
          }
          request {
            display_type = "line"
            q            = "avg:system.cpu.system{karpenter_nodepool:airflow,env:${var.environment}} by {host}"
            style {
              line_type  = "solid"
              line_width = "thin"
              palette    = "warm"
            }
          }
          yaxis {
            include_zero = true
            max          = "100"
            min          = "0"
          }
        }
      }
      widget {
        timeseries_definition {
          show_legend = true
          title       = "노드 메모리 사용량 (GB)"
          request {
            display_type = "area"
            q            = "avg:system.mem.used{karpenter_nodepool:airflow,env:${var.environment}} by {host} / 1073741824"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "purple"
            }
          }
          request {
            display_type = "line"
            q            = "avg:system.mem.total{karpenter_nodepool:airflow,env:${var.environment}} by {host} / 1073741824"
            style {
              line_type  = "dashed"
              line_width = "normal"
              palette    = "grey"
            }
          }
        }
      }
    }
  }
  widget {
    group_definition {
      layout_type = "ordered"
      show_title  = true
      title       = "🐳 Pod 리소스 (airflow-green)"
      widget {
        timeseries_definition {
          show_legend = true
          title       = "Pod CPU 사용량 (cores)"
          request {
            display_type = "line"
            q            = "avg:kubernetes.cpu.usage.total{kube_namespace:airflow-green,cluster_name:${var.cluster_name}} by {pod_name} / 1000000000"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "dog_classic"
            }
          }
        }
      }
      widget {
        timeseries_definition {
          show_legend = true
          title       = "Pod 메모리 사용량 (MB)"
          request {
            display_type = "area"
            q            = "avg:kubernetes.memory.working_set{kube_namespace:airflow-green,cluster_name:${var.cluster_name}} by {pod_name} / 1048576"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "purple"
            }
          }
        }
      }
    }
  }
  widget {
    group_definition {
      layout_type = "ordered"
      show_title  = true
      title       = "⚙️ 스케줄러"
      widget {
        timeseries_definition {
          show_legend = false
          title       = "Scheduler Heartbeat (beat/min)"
          request {
            display_type = "bars"
            q            = "sum:airflow.scheduler.heartbeat{cluster_name:${var.cluster_name}}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "green"
            }
          }
        }
      }
      widget {
        timeseries_definition {
          show_legend = false
          title       = "DAG 파싱 시간 (초)"
          request {
            display_type = "line"
            q            = "avg:airflow.dag_processing.total_parse_time{cluster_name:${var.cluster_name}}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "orange"
            }
          }
        }
      }
    }
  }
  widget {
    group_definition {
      layout_type = "ordered"
      show_title  = true
      title       = "📋 태스크 & 풀"
      widget {
        timeseries_definition {
          show_legend = true
          title       = "태스크 상태 (Running / Starving / Killed)"
          request {
            display_type = "line"
            q            = "avg:airflow.scheduler.tasks.running{cluster_name:${var.cluster_name}}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "green"
            }
          }
          request {
            display_type = "line"
            q            = "avg:airflow.scheduler.tasks.starving{cluster_name:${var.cluster_name}}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "orange"
            }
          }
          request {
            display_type = "bars"
            q            = "sum:airflow.scheduler.tasks.killed_externally{cluster_name:${var.cluster_name}}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "red"
            }
          }
        }
      }
      widget {
        timeseries_definition {
          show_legend = true
          title       = "풀 슬롯 by pool"
          request {
            display_type = "area"
            q            = "avg:airflow.pool.running_slots{cluster_name:${var.cluster_name}} by {pool_name}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "green"
            }
          }
          request {
            display_type = "area"
            q            = "avg:airflow.pool.queued_slots{cluster_name:${var.cluster_name}} by {pool_name}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "orange"
            }
          }
          request {
            display_type = "line"
            q            = "avg:airflow.pool.open_slots{cluster_name:${var.cluster_name}} by {pool_name}"
            style {
              line_type  = "dashed"
              line_width = "normal"
              palette    = "grey"
            }
          }
        }
      }
    }
  }
  widget {
    group_definition {
      layout_type = "ordered"
      show_title  = true
      title       = "🔄 DAG Run"
      widget {
        timeseries_definition {
          show_legend = true
          title       = "DAG Run 지속시간 (초) — Success vs Failed"
          request {
            display_type = "line"
            q            = "avg:airflow.dagrun.duration.success{cluster_name:${var.cluster_name}} by {dag_id}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "green"
            }
          }
          request {
            display_type = "bars"
            q            = "avg:airflow.dagrun.duration.failed{cluster_name:${var.cluster_name}} by {dag_id}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "red"
            }
          }
        }
      }
      widget {
        timeseries_definition {
          show_legend = true
          title       = "DAG Run 스케줄 지연 (초)"
          request {
            display_type = "line"
            q            = "avg:airflow.dagrun.schedule_delay{cluster_name:${var.cluster_name}} by {dag_id}"
            style {
              line_type  = "solid"
              line_width = "normal"
              palette    = "orange"
            }
          }
        }
      }
    }
  }
  widget {
    log_stream_definition {
      columns = [
        "core_host",
        "core_service",
        "core_status",
      ]
      message_display     = "expanded-md"
      query               = "kube_namespace:airflow-green OR kube_namespace:airflow"
      show_date_column    = true
      show_message_column = true
      title               = "📝 Airflow 로그"
      sort {
        column = "time"
        order  = "desc"
      }
    }
  }
}
