locals {
  cluster_name = data.terraform_remote_state.env.outputs.cluster_name
  tags         = data.terraform_remote_state.env.outputs.default_tags
}
