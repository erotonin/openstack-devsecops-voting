output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN for GitHub Actions"
}

output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS Cluster name"
}

output "ecr_repository_urls" {
  value       = module.ecr.repository_urls
  description = "ECR Repository URLs"
}
