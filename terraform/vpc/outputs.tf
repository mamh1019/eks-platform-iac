output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID for workload shared infrastructure"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnets
  description = "Public subnet IDs"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnets
  description = "Private subnet IDs"
}

output "availability_zones" {
  value = module.vpc.azs
}
