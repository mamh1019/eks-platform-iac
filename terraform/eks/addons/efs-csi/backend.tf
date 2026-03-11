terraform {
  backend "s3" {
    key = "eks-addons/efs-csi/terraform.tfstate"
  }
}
