############################################
# terraform/efs/main.tf — EKS 노드(예: app-nodes)에서 사용할 EFS
############################################

locals {
  # EKS destroy 후에는 outputs 없음 → try로 평가만 통과시키기
  cluster_name = try(data.terraform_remote_state.eks.outputs.cluster_name, "")
  name        = "workload-efs"
  tags        = merge(
    data.terraform_remote_state.env.outputs.default_tags,
    { Name = local.name }
  )
}

# --- EFS 파일 시스템 ---
resource "aws_efs_file_system" "this" {
  creation_token = local.name
  encrypted      = true

  tags = local.tags
}

# --- EFS용 보안 그룹: EKS 노드에서 NFS(2049) 접근 허용 ---
resource "aws_security_group" "efs" {
  name_prefix = "${local.name}-"
  description = "EFS mount target; allow NFS from EKS nodes"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    description     = "NFS from EKS nodes"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = try([data.terraform_remote_state.eks.outputs.node_security_group_id], [])
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = local.name })
  lifecycle { create_before_destroy = true }
}

# --- Mount Target: Private 서브넷당 1개 (EKS 노드와 동일 서브넷) ---
resource "aws_efs_mount_target" "this" {
  for_each = toset(data.terraform_remote_state.vpc.outputs.private_subnet_ids)

  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

# --- EFS Access Point: Grafana 전용 (/grafana 경로) ---
# Grafana UID/GID 472 (init-chown-data가 EFS에서 실패하므로 Access Point에서 지정)
resource "aws_efs_access_point" "grafana" {
  file_system_id = aws_efs_file_system.this.id

  root_directory {
    path = "/grafana"
    creation_info {
      owner_gid   = 472
      owner_uid   = 472
      permissions = "755"
    }
  }

  posix_user {
    gid = 472
    uid = 472
  }

  tags = merge(local.tags, { Name = "${local.name}-grafana" })
}

# --- EFS Access Point: Prometheus 메트릭 전용 (/prometheus 경로) ---
resource "aws_efs_access_point" "prometheus" {
  file_system_id = aws_efs_file_system.this.id

  root_directory {
    path = "/prometheus"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }

  tags = merge(local.tags, { Name = "${local.name}-prometheus" })
}
