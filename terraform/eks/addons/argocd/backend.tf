terraform {
  backend "s3" {
    key = "eks-addons/argocd/terraform.tfstate"
  }
}
