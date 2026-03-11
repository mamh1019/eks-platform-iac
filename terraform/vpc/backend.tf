terraform {
  backend "s3" {
    key = "vpc/terraform.tfstate"
  }
}
