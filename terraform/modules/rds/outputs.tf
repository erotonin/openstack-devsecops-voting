output "endpoint" {
  description = "RDS endpoint (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "RDS DNS hostname (không port)"
  value       = aws_db_instance.main.address
}

output "port" {
  value = aws_db_instance.main.port
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

output "instance_id" {
  value = aws_db_instance.main.id
}

output "instance_arn" {
  value = aws_db_instance.main.arn
}

output "instance_resource_id" {
  description = "Resource ID (cho IAM DB auth)"
  value       = aws_db_instance.main.resource_id
}

output "kms_key_arn" {
  value = aws_kms_key.rds.arn
}
