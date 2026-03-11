variable "app_node_groups" {
  description = "App-specific NodePools. Key = app name (nodepool label for nodeSelector)."
  type = map(object({
    instance_types = optional(list(string), ["m7g.large", "c7g.large"])
    min_size       = optional(number, 1)
    max_size       = optional(number, 3)
    desired_size   = optional(number, 1)
    limit_cpu      = optional(string)
    limit_memory   = optional(string)
  }))
  default = {
    app-web = {
      instance_types = ["m7g.large"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      limit_cpu      = "4"
      limit_memory   = "16Gi"
    }
    app-api = {
      instance_types = ["m7g.large"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      limit_cpu      = "4"
      limit_memory   = "16Gi"
    }
  }
}
