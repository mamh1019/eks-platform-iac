# External Secrets Operator — AWS Secrets Manager 연동 (Pod Identity)
# IAM 역할은 별도(iam 레이어)에서 생성 후 output: external_secrets_role_arn

locals {
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
  role_arn     = data.terraform_remote_state.iam.outputs.external_secrets_role_arn
  aws_region   = data.terraform_remote_state.env.outputs.aws_region
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "kubernetes_service_account_v1" "external_secrets" {
  metadata {
    name      = "external-secrets"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name
  }
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = local.cluster_name
  namespace       = kubernetes_namespace_v1.external_secrets.metadata[0].name
  service_account = kubernetes_service_account_v1.external_secrets.metadata[0].name
  role_arn        = local.role_arn
}

resource "helm_release" "external_secrets" {
  repository       = "https://charts.external-secrets.io"
  name             = "external-secrets"
  chart            = "external-secrets"
  version          = "0.9.11"
  namespace        = kubernetes_namespace_v1.external_secrets.metadata[0].name
  create_namespace = false

  values = [
    <<-EOT
    serviceAccount:
      create: false
      name: ${kubernetes_service_account_v1.external_secrets.metadata[0].name}
    # 코어 노드에만 스케줄
    nodeSelector:
      nodepool: core
    EOT
  ]

  depends_on = [aws_eks_pod_identity_association.external_secrets]
}

resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = local.aws_region
        }
      }
    }
  }
  depends_on = [helm_release.external_secrets]
}
