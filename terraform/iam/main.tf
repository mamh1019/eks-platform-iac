locals {
  cluster_name = data.terraform_remote_state.env.outputs.cluster_name
  aws_region   = data.terraform_remote_state.env.outputs.aws_region

  # IAM은 계정 글로벌이라 리전 포함으로 충돌 방지
  name_suffix = "${local.cluster_name}-${local.aws_region}"

  tags = data.terraform_remote_state.env.outputs.default_tags
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${local.name_suffix}-alb-controller-policy"
  policy = file("${path.module}/policies/alb_controller.json")

  tags = merge(local.tags, {
    Name = "${local.name_suffix}-alb-controller-policy"
  })
}

resource "aws_iam_role" "alb_controller" {
  name = "${local.name_suffix}-alb-controller"

  # Pod Identity trust policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = merge(local.tags, {
    Name = "${local.name_suffix}-alb-controller"
  })
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# --- EBS CSI Driver (EKS Pod Identity, cluster addon) ---
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${local.name_suffix}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = merge(local.tags, {
    Name = "${local.name_suffix}-ebs-csi-driver"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# --- EFS CSI Driver (EKS Pod Identity) ---
resource "aws_iam_role" "efs_csi_driver" {
  name = "${local.name_suffix}-efs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = merge(local.tags, {
    Name = "${local.name_suffix}-efs-csi-driver"
  })
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  role       = aws_iam_role.efs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

# --- External Secrets Operator (EKS Pod Identity) ---
resource "aws_iam_policy" "external_secrets" {
  name   = "${local.name_suffix}-external-secrets-policy"
  policy = file("${path.module}/policies/external_secrets.json")

  tags = merge(local.tags, {
    Name = "${local.name_suffix}-external-secrets-policy"
  })
}

resource "aws_iam_role" "external_secrets" {
  name = "${local.name_suffix}-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })

  tags = merge(local.tags, {
    Name = "${local.name_suffix}-external-secrets"
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}
