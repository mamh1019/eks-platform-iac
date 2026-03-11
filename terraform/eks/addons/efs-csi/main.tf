############################################
# terraform/eks/addons/efs-csi — EFS CSI Driver + StorageClass (동적 프로비저닝)
############################################

locals {
  cluster_name   = data.terraform_remote_state.eks.outputs.cluster_name
  role_arn       = data.terraform_remote_state.iam.outputs.efs_csi_driver_role_arn
  file_system_id = data.terraform_remote_state.efs.outputs.file_system_id
}

# --- Controller SA + Pod Identity ---
resource "kubernetes_service_account_v1" "efs_csi_controller" {
  metadata {
    name      = "efs-csi-controller-sa"
    namespace = "kube-system"
  }
}

resource "aws_eks_pod_identity_association" "efs_csi_controller" {
  cluster_name    = local.cluster_name
  namespace       = "kube-system"
  service_account = kubernetes_service_account_v1.efs_csi_controller.metadata[0].name
  role_arn        = local.role_arn
}

# --- Node SA + Pod Identity (node daemonset도 EFS Describe 등 권한 사용) ---
resource "kubernetes_service_account_v1" "efs_csi_node" {
  metadata {
    name      = "efs-csi-node-sa"
    namespace = "kube-system"
  }
}

resource "aws_eks_pod_identity_association" "efs_csi_node" {
  cluster_name    = local.cluster_name
  namespace       = "kube-system"
  service_account = kubernetes_service_account_v1.efs_csi_node.metadata[0].name
  role_arn        = local.role_arn
}

# --- Helm: aws-efs-csi-driver ---
resource "helm_release" "efs_csi_driver" {
  name       = "aws-efs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "3.4.0"

  set = [
    { name = "controller.serviceAccount.create", value = "false" },
    { name = "controller.serviceAccount.name", value = kubernetes_service_account_v1.efs_csi_controller.metadata[0].name },
    { name = "node.serviceAccount.create", value = "false" },
    { name = "node.serviceAccount.name", value = kubernetes_service_account_v1.efs_csi_node.metadata[0].name },
  ]

  # Controller: 코어 노드에만 스케줄. Node DaemonSet: nodepool taint 허용
  values = [
    <<-EOT
    controller:
      nodeSelector:
        nodepool: core
    node:
      tolerations:
        - operator: Exists
        - key: nodepool
          operator: Exists
          effect: NoSchedule
    EOT
  ]

  depends_on = [
    aws_eks_pod_identity_association.efs_csi_controller,
    aws_eks_pod_identity_association.efs_csi_node,
  ]
}

# --- 정적 PV: EFS 루트 마운트 (웹 앱 전용) ---
resource "kubernetes_persistent_volume_v1" "efs_web" {
  metadata {
    name = "efs-web"
  }
  spec {
    capacity = {
      storage = "10Gi"
    }
    volume_mode                        = "Filesystem"
    access_modes                       = ["ReadWriteMany"]
    storage_class_name                 = ""
    persistent_volume_reclaim_policy   = "Retain"
    persistent_volume_source {
      csi {
        driver         = "efs.csi.aws.com"
        volume_handle  = local.file_system_id
      }
    }
  }
  depends_on = [helm_release.efs_csi_driver]
}

# --- StorageClass: Grafana (uid/gid 472, initChownData 불필요) ---
resource "kubernetes_storage_class_v1" "efs_grafana" {
  metadata {
    name = "efs-grafana-sc"
  }
  storage_provisioner    = "efs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = false

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = local.file_system_id
    directoryPerms   = "700"
    uid              = "472"
    gid              = "472"
  }
}

# --- StorageClass: Prometheus / Alertmanager (uid/gid 1000) ---
resource "kubernetes_storage_class_v1" "efs_prometheus" {
  metadata {
    name = "efs-prometheus-sc"
  }
  storage_provisioner    = "efs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = false

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = local.file_system_id
    directoryPerms   = "700"
    uid              = "1000"
    gid              = "1000"
  }
}
