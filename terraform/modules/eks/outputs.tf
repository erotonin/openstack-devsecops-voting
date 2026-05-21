output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "EKS managed cluster SG (auto created)"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN cho IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL (không có https://)"
  value       = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

output "oidc_provider_full_url" {
  description = "OIDC issuer URL có https://"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "node_group_name" {
  value = aws_eks_node_group.main.node_group_name
}

output "node_role_arn" {
  value = aws_iam_role.eks_nodes.arn
}

output "node_role_name" {
  value = aws_iam_role.eks_nodes.name
}

output "kms_key_arn_secrets" {
  value = aws_kms_key.eks.arn
}

output "kms_key_arn_ebs" {
  value = aws_kms_key.ebs.arn
}
