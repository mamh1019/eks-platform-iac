terraform {
  backend "s3" {
    key = "eks-addons/external-secrets/terraform.tfstate"
  }
}
