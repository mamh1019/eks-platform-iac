############################################
# terraform/eks/main.tf
############################################

# --- Who am I (for access entry) ---
data "aws_caller_identity" "current" {}

# --- EKS Cluster ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.15.1"

  name               = local.cluster_name
  kubernetes_version = "1.35"

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

  # Karpenter가 노드용 보안 그룹을 찾을 수 있도록 (이 태그는 노드 SG 하나에만 붙일 것)
  node_security_group_tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.cluster_name
  })

  endpoint_public_access  = true
  endpoint_private_access = true

  # ---------------------------------------------------------------------------
  # CloudWatch Control Plane 로깅
  # ---------------------------------------------------------------------------
  # 로그 끄기 (비용 절감)
  enabled_log_types = []

  # 로그 켜기 + 보존 기간 (주석 해제 후 옵션 A 주석 처리)
  # enabled_log_types                      = ["api", "audit", "authenticator"]
  # cloudwatch_log_group_retention_in_days = 7   # 7일 후 자동 삭제 (비용 관리)
  # cloudwatch_log_group_class             = "INFREQUENT_ACCESS"

  # Access Entry 기반 인증/인가 (kubectl 권한 부여)
  authentication_mode = "API"
  access_entries = merge(
    {
      admin = {
        principal_arn = data.aws_caller_identity.current.arn
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      }
    },
    # 다른 경로에서 apply 하는 계정 (env remote state 에서 읽음). EKS apply 실행자와 동일한 ARN은 제외(이미 admin에 있음)
    {
      for i, arn in data.terraform_remote_state.env.outputs.additional_admin_principal_arns : "admin_${i}" => {
        principal_arn = arn
        policy_associations = {
          admin = {
            policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = { type = "cluster" }
          }
        }
      } if arn != data.aws_caller_identity.current.arn
    }
  )

  # v21: before_compute = true → 노드 그룹 생성 전에 addon 설치 (CNI 없이 노드 부팅 방지)
  # coredns는 Deployment라 노드 필요 → false (노드 후 설치)
  addons = {
    coredns                = { most_recent = true, before_compute = false }
    kube-proxy             = { most_recent = true, before_compute = true }
    vpc-cni                = { most_recent = true, before_compute = true }
    eks-pod-identity-agent = { most_recent = true, before_compute = true }

    aws-ebs-csi-driver = {
      most_recent    = true
      before_compute = false  # Deployment - 노드 필요
      pod_identity_association = [
        {
          role_arn        = data.terraform_remote_state.iam.outputs.ebs_csi_driver_role_arn
          service_account = "ebs-csi-controller-sa"
        }
      ]
    }

    metrics-server = {
      most_recent    = true
      before_compute = false  # Deployment - HPA용 CPU/메모리 메트릭
    }
  }

  eks_managed_node_groups = merge(
    {
      core_graviton = {
        name          = "${local.cluster_name}-core-g"
        capacity_type = "ON_DEMAND"

        iam_role_use_name_prefix = false
        iam_role_name            = "dw-eks-core-graviton-ng"

        ami_type       = "AL2023_ARM_64_STANDARD"
        instance_types = ["m7g.large", "c7g.large"]

        min_size     = 1
        max_size     = 2
        desired_size = 1

        subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

        labels = {
          nodepool                    = "core"
          arch                        = "arm64"
          "karpenter.sh/controller"   = "true"  # Karpenter 컨트롤러가 이 노드에만 스케줄됨
        }

        tags = merge(local.tags, {
          Name = "${local.cluster_name}-core-arm64"
        })
      }

      monitoring_graviton = {
        name          = "${local.cluster_name}-monitoring-g"
        capacity_type = "ON_DEMAND"

        iam_role_use_name_prefix = false
        iam_role_name            = "dw-eks-monitoring-graviton-ng"

        ami_type       = "AL2023_ARM_64_STANDARD"
        instance_types = ["m7g.large"]

        min_size     = 1
        max_size     = 1
        desired_size = 1

        subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids

        block_device_mappings = {
          xvda = {
            device_name = "/dev/xvda"
            ebs = {
              volume_size           = 20
              volume_type           = "gp3"
              delete_on_termination = true
            }
          }
        }

        labels = {
          nodepool = "monitoring"
          arch     = "arm64"
        }

        tags = merge(local.tags, {
          Name = "${local.cluster_name}-monitoring-arm64"
        })
      }
    }
    # 앱별 노드는 Karpenter NodePool로 오토스케일 (terraform/eks/karpenter/ 에서 별도 apply)
  )

  tags = merge(local.tags, { Name = local.cluster_name })
}
