locals {
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
  role_arn     = data.terraform_remote_state.iam.outputs.alb_controller_role_arn
}

resource "kubernetes_service_account_v1" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }
}

resource "aws_eks_pod_identity_association" "alb_controller" {
  cluster_name    = local.cluster_name
  namespace       = "kube-system"
  service_account = kubernetes_service_account_v1.alb_controller.metadata[0].name
  role_arn        = local.role_arn
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.1.0"

  create_namespace = true

  set = [
    { name = "clusterName", value = local.cluster_name },
    { name = "serviceAccount.create", value = "false" },
    { name = "serviceAccount.name", value = kubernetes_service_account_v1.alb_controller.metadata[0].name },
    { name = "replicaCount", value = "1" },  # 코어 노드 1개일 때 2레플은 Pending → Ready 불가
    { name = "region", value = data.terraform_remote_state.env.outputs.aws_region },
    { name = "vpcId", value = data.terraform_remote_state.vpc.outputs.vpc_id },  # 메타데이터 타임아웃 시 명시 지정
    { name = "nodeSelector.nodepool", value = "core" },  # 코어 노드에만 스케줄
  ]

  depends_on = [aws_eks_pod_identity_association.alb_controller]
}

