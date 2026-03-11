output "file_system_id" {
  value       = aws_efs_file_system.this.id
  description = "EFS File System ID (정적 PV 파라미터에 사용)"
}

output "file_system_arn" {
  value       = aws_efs_file_system.this.arn
  description = "EFS File System ARN"
}

output "grafana_access_point_id" {
  value       = aws_efs_access_point.grafana.id
  description = "EFS Access Point ID for Grafana (/grafana)"
}

output "prometheus_access_point_id" {
  value       = aws_efs_access_point.prometheus.id
  description = "EFS Access Point ID for Prometheus (/prometheus)"
}
