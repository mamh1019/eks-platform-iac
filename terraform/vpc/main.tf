data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  vpc_name = "${data.terraform_remote_state.env.outputs.project}-vpc"

  az_count = 4
  azs      = slice(data.aws_availability_zones.available.names, 0, min(local.az_count, length(data.aws_availability_zones.available.names)))

  # 10.20.0.0/16 → /19 subnet (실제 사용 AZ 수 * 2개)
  vpc_cidr        = data.terraform_remote_state.env.outputs.vpc_cidr
  public_subnets  = [for i in range(length(local.azs)) : cidrsubnet(local.vpc_cidr, 3, i)]
  private_subnets = [for i in range(length(local.azs)) : cidrsubnet(local.vpc_cidr, 3, i + length(local.azs))]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = local.vpc_name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = true   # 비용 때문에 NAT 1개만 사용
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC + IGW + RT + NAT + EIP 전반 태그
  tags = merge(
    data.terraform_remote_state.env.outputs.default_tags,
    { Name = local.vpc_name }
  )

  # Public Subnet (ALB용)
  public_subnet_tags = merge(
    data.terraform_remote_state.env.outputs.default_tags,
    {
      Name                                        = "${local.vpc_name}-public"
      "kubernetes.io/role/elb"                    = "1"
      "kubernetes.io/cluster/${data.terraform_remote_state.env.outputs.cluster_name}" = "shared"
    }
  )

  # Private Subnet (EKS Pod / Internal ALB, Karpenter discovery)
  private_subnet_tags = merge(
    data.terraform_remote_state.env.outputs.default_tags,
    {
      Name                                        = "${local.vpc_name}-private"
      "kubernetes.io/role/internal-elb"           = "1"
      "kubernetes.io/cluster/${data.terraform_remote_state.env.outputs.cluster_name}" = "shared"
      "karpenter.sh/discovery"                   = data.terraform_remote_state.env.outputs.cluster_name
    }
  )
}
