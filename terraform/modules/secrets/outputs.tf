output "secret_arn" {
  value = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.this.name
}

output "kms_key_arn" {
  value = aws_kms_key.secret.arn
}

output "password" {
  description = "Generated password (sensitive)"
  value       = var.generate_password ? random_password.this[0].result : null
  sensitive   = true
}
