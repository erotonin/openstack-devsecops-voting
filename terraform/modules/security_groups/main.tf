locals {
  common_tags = merge(var.tags, {
    Module    = "security_groups"
    ManagedBy = "terraform"
  })
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB ingress HTTPS and HTTP from internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP redirect to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Forward to EKS pods"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS Postgres only from EKS pods"
  vpc_id      = var.vpc_id

  ingress {
    description = "Postgres from EKS workload"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.eks_pod_cidrs
  }

  ingress {
    description = "Postgres from peer Azure VPN"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.peer_vpc_cidrs
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-rds-sg"
  })
}

resource "aws_security_group" "elasticache" {
  name        = "${var.name_prefix}-elasticache-sg"
  description = "ElastiCache Redis only from EKS pods"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redis from EKS workload"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = var.eks_pod_cidrs
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-elasticache-sg"
  })
}

resource "aws_security_group" "eks_node_extra" {
  name        = "${var.name_prefix}-eks-node-extra-sg"
  description = "Extra rules for EKS node"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All egress for image pulls and API calls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name                                        = "${var.name_prefix}-eks-node-extra-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

resource "aws_security_group" "vpn" {
  name        = "${var.name_prefix}-vpn-sg"
  description = "Site-to-site VPN to Azure"
  vpc_id      = var.vpc_id

  ingress {
    description = "IPSec from Azure VPN GW"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = var.peer_vpc_cidrs
  }

  ingress {
    description = "IPSec NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = var.peer_vpc_cidrs
  }

  ingress {
    description = "ESP"
    from_port   = 0
    to_port     = 0
    protocol    = "50"
    cidr_blocks = var.peer_vpc_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpn-sg"
  })
}
