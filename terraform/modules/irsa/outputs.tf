output "role_arn" {
  description = "IAM Role ARN — gắn vào ServiceAccount qua annotation eks.amazonaws.com/role-arn"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  value = aws_iam_role.this.name
}
