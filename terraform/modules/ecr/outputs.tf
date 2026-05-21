output "repository_urls" {
  value = aws_ecr_repository.repo[*].repository_url
}

output "repository_arns" {
  value = aws_ecr_repository.repo[*].arn
}

output "repository_names" {
  value = aws_ecr_repository.repo[*].name
}
