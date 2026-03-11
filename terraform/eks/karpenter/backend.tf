terraform {
  backend "s3" {
    key = "eks-karpenter/terraform.tfstate"
  }
}
