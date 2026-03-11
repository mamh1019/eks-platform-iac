data "terraform_remote_state" "env" {
  backend = "s3"
  config = {
    bucket = "example-eks-infra-tfstate"
    key    = "env/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "example-eks-infra-tfstate"
    key    = "eks/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
