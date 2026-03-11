# -----------------------------------------------------------------------------
# ArgoCD (Helm)
# -----------------------------------------------------------------------------

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.7.10"
  namespace  = "argocd"

  create_namespace = true

  set = [
    { name = "server.service.type", value = "ClusterIP" },
    { name = "configs.secret.createSecret", value = "true" },
    # HTTP 모드로 동작 → ALB가 80으로 백엔드 호출
    { name = "configs.params.server\\.insecure", value = "true" },
    # 코어 노드에만 스케줄
    { name = "server.nodeSelector.nodepool", value = "core" },
    { name = "controller.nodeSelector.nodepool", value = "core" },
    { name = "repoServer.nodeSelector.nodepool", value = "core" },
    { name = "applicationSet.nodeSelector.nodepool", value = "core" },
  ]
}

# -----------------------------------------------------------------------------
# Ingress (ALB): User → ALB → Ingress → argocd-server Service → Pod
# -----------------------------------------------------------------------------
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
    annotations = {
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
  }
  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port { number = 80 }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.argocd]
}
