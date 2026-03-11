provider "aws" {
  region = data.terraform_remote_state.env.outputs.aws_region
}
