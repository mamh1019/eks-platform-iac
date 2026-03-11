terraform {
  backend "s3" {
    key = "eks-addons/monitoring/terraform.tfstate"
  }
}
