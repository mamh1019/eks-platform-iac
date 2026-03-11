provider "aws" {
  region = data.terraform_remote_state.env.outputs.aws_region
}

# Karpenter는 terraform/eks/karpenter/ 에서 별도 적용 (EKS 생성 후)
