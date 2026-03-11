############################################
# Karpenter: 앱별 NodePool 오토스케일 (EKS 생성 후 이 디렉터리에서 apply)
############################################

data "aws_eks_cluster" "cluster" {
  name = local.cluster_name
}

data "aws_ecrpublic_authorization_token" "karpenter" {
  provider = aws.us_east_1
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.15.1"

  cluster_name = local.cluster_name

  create_pod_identity_association = true
  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = "KarpenterNodeRole-${local.cluster_name}"
  create_instance_profile         = false

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  enable_spot_termination = true  # false면 queue 미생성 → queue_name null → helm values 에러
  tags                    = local.tags
}

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.karpenter.user_name
  repository_password = data.aws_ecrpublic_authorization_token.karpenter.password
  chart               = "karpenter"
  version             = "1.9.0"
  wait                = false

  values = [
    <<-EOT
    # 코어 노드 수대로 설정 (karpenter.sh/controller 라벨이 붙은 노드 = 컨트롤러 전용)
    replicas: 1
    nodeSelector:
      karpenter.sh/controller: "true"
    dnsPolicy: Default
    settings:
      clusterName: ${data.aws_eks_cluster.cluster.name}
      clusterEndpoint: ${data.aws_eks_cluster.cluster.endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    webhook:
      enabled: false
    EOT
  ]
}

# 노드풀별 EC2NodeClass (EC2 Name 태그로 구분: 클러스터명-노드풀명)
resource "kubernetes_manifest" "karpenter_ec2_node_class" {
  for_each = var.app_node_groups

  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = each.key
    }
    spec = {
      amiFamily = "AL2023"
      role      = module.karpenter.node_iam_role_name
      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = local.cluster_name } }
      ]
      securityGroupSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = local.cluster_name } }
      ]
      amiSelectorTerms = [
        { alias = "al2023@latest" }
      ]
      tags = merge(local.tags, {
        Name               = "${local.cluster_name}-${each.key}"
        KarpenterNodePool  = each.key
      })
    }
  }

  depends_on = [helm_release.karpenter]
}

# NodePool (v1). labels는 template.metadata에 두어 provider 스키마 검증 통과
resource "kubernetes_manifest" "karpenter_node_pool" {
  for_each = var.app_node_groups

  computed_fields = ["metadata.managedFields", "status"]

  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = each.key
    }
    spec = {
      # 파드가 없거나 사용률이 낮은 노드를 자동으로 정리(consolidation)
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "30s"
      }
      template = {
        metadata = {
          labels = {
            nodepool = each.key
            arch     = "arm64"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = each.key
          }
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["arm64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
            { key = "node.kubernetes.io/instance-type", operator = "In", values = each.value.instance_types }
          ]
          taints = [
            {
              key    = "nodepool"
              value  = each.key
              effect = "NoSchedule"
            }
          ]
        }
      }
      limits = {
        cpu    = coalesce(try(each.value.limit_cpu, null), tostring(each.value.max_size * 4))
        memory = coalesce(try(each.value.limit_memory, null), "${each.value.max_size * 8}Gi")
      }
    }
  }

  depends_on = [kubernetes_manifest.karpenter_ec2_node_class]
}
