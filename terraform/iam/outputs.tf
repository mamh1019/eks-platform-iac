output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "ebs_csi_driver_role_arn" {
  value = aws_iam_role.ebs_csi_driver.arn
}

output "alb_controller_policy_arn" {
  value = aws_iam_policy.alb_controller.arn
}

output "efs_csi_driver_role_arn" {
  value = aws_iam_role.efs_csi_driver.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}
