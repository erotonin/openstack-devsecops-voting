output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (cho ALB, NAT GW)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (cho EKS node group)"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "Database subnet IDs (cho RDS)"
  value       = aws_subnet.database[*].id
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs (1 per AZ) — dùng cho egress IP allowlist của 3rd party API"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "azs" {
  description = "Availability Zones used"
  value       = var.azs
}
