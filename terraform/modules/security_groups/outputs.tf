output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "elasticache_sg_id" {
  value = aws_security_group.elasticache.id
}

output "eks_node_extra_sg_id" {
  value = aws_security_group.eks_node_extra.id
}

output "vpn_sg_id" {
  value = aws_security_group.vpn.id
}
