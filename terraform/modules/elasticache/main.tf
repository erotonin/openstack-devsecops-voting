locals {
  common_tags = merge(var.tags, {
    Module    = "elasticache"
    ManagedBy = "terraform"
  })
}

resource "aws_kms_key" "redis" {
  description             = "KMS key for Redis ${var.name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-redis-kms"
  })
}

resource "aws_kms_alias" "redis" {
  name          = "alias/${var.name}-redis"
  target_key_id = aws_kms_key.redis.key_id
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = local.common_tags
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = var.name
  description                = "Redis replication group for ${var.name}"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  port                       = 6379
  parameter_group_name       = var.parameter_group_name
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = var.security_group_ids
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn
  auth_token                 = var.auth_token
  automatic_failover_enabled = var.num_cache_clusters > 1
  multi_az_enabled           = var.num_cache_clusters > 1
  num_cache_clusters         = var.num_cache_clusters
  apply_immediately          = var.apply_immediately

  log_delivery_configuration {
    destination      = var.log_group_name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = local.common_tags
}

