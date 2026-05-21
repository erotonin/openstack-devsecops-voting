output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN for GitHub Actions"
}

output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS Cluster name"
}

output "aws_region" {
  value       = var.aws_region
  description = "AWS region"
}

output "ecr_repository_urls" {
  value       = module.ecr.repository_urls
  description = "ECR Repository URLs"
}

output "rds_endpoint" {
  value       = module.rds.endpoint
  description = "RDS PostgreSQL endpoint"
}

output "redis_endpoint" {
  value       = module.elasticache.primary_endpoint_address
  description = "ElastiCache Redis primary endpoint"
}

output "db_secret_name" {
  value       = module.db_secret.secret_name
  description = "AWS Secrets Manager DB secret name"
}

output "redis_secret_name" {
  value       = module.redis_secret.secret_name
  description = "AWS Secrets Manager Redis secret name"
}
