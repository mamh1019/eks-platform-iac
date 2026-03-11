output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

# EFS 등에서 EKS 노드가 NFS(2049) 접근할 수 있도록 SG 참조용
output "node_security_group_id" {
  value       = module.eks.node_security_group_id
  description = "EKS 노드 공용 보안 그룹 ID (EFS Mount Target SG에서 2049 허용 시 사용)"
}
