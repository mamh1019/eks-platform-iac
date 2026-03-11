# -----------------------------------------------------------------------------
# Prometheus + Grafana (kube-prometheus-stack)
# 노드/파드 메트릭 수집, Grafana UI에서 알림/대시보드 설정
# -----------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "67.2.0"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name

  create_namespace = false

  values = [
    yamlencode({
      # 모니터링 전용 노드 그룹(nodepool=monitoring)에만 스케줄
      defaultRules = {
        create = true
        rules = {
          alertmanager            = true
          etcd                    = false
          kubernetesControlPlane   = false
          kubernetesResources      = true
          kubernetesStorage        = true
          kubernetesSystem         = true
          network                 = false
          node                    = true
          prometheus              = true
          prometheusOperator      = true
        }
      }

      prometheus = {
        prometheusSpec = {
          retention = "15d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "efs-prometheus-sc"
                accessModes      = ["ReadWriteMany"]
                resources = {
                  requests = {
                    storage = "20Gi"
                  }
                }
              }
            }
          }
          nodeSelector = {
            nodepool = "monitoring"
          }
        }
      }

      alertmanager = {
        enabled = true
        alertmanagerSpec = {
          nodeSelector = {
            nodepool = "monitoring"
          }
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "efs-prometheus-sc"
                accessModes      = ["ReadWriteMany"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
        # 기본 null receiver (Slack 등은 Grafana UI에서 설정)
        config = {
          global = { resolve_timeout = "5m" }
          route = {
            group_by       = ["alertname", "namespace"]
            group_wait     = "30s"
            group_interval = "5m"
            repeat_interval = "12h"
            receiver       = "null"
            routes         = [{ receiver = "null", matchers = ["alertname = Watchdog"] }]
          }
          receivers = [{ name = "null" }]
        }
      }

      grafana = {
        enabled                   = true
        defaultDashboardsEnabled  = true
        initChownData             = { enabled = false }
        persistence = {
          enabled          = true
          storageClassName = "efs-grafana-sc"
          accessModes      = ["ReadWriteMany"]
          size             = "10Gi"
        }
        nodeSelector = {
          nodepool = "monitoring"
        }
      }

      # node-exporter: DaemonSet, 모든 노드에서 실행 (노드별 메트릭 수집)
      nodeExporter = {
        enabled = true
      }
      # kube-state-metrics: 모니터링 노드에 스케줄
      kubeStateMetrics = {
        enabled     = true
        nodeSelector = { nodepool = "monitoring" }
      }
    })
  ]

  depends_on = [kubernetes_namespace_v1.monitoring]
}

# -----------------------------------------------------------------------------
# 커스텀 PrometheusRule 제거: Grafana UI에서 알림 설정 (EFS에 영구 저장)
# 인프라 변경 없이 자주 수정 가능
# -----------------------------------------------------------------------------
