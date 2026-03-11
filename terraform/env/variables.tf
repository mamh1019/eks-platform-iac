variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project" {
  type    = string
  default = "example-eks-infra"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for shared workload VPC"
  default     = "10.20.0.0/16"
}

variable "cluster_name" {
  type    = string
  default = "example-eks-infra-eks"
}

variable "default_tags" {
  type = map(string)
  default = {
    createdBy        = "example-eks-infra"
    createdByProject = "example-eks-infra"
    ManagedBy        = "terraform"
  }
}

# EKS 클러스터 Admin 권한을 줄 IAM principal ARN
variable "additional_admin_principal_arns" {
  type        = list(string)
  description = "IAM principals to grant EKS cluster admin (e.g. arn:aws:iam::ACCOUNT_ID:user/your-admin-user)."
  default     = []
}
