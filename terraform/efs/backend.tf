terraform {
  backend "s3" {
    key = "efs/terraform.tfstate"
  }
}
