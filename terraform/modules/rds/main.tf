# ─────────────────────────────────────────────────────────────────
# RDS PostgreSQL Module — Multi-AZ Production-grade
#
# Bao gồm:
#   - KMS key riêng cho RDS encryption at-rest
#   - DB Subnet Group (multi-AZ private DB subnet)
#   - Parameter Group (force SSL, log_min_duration)
#   - Multi-AZ Postgres instance + automated backup + PITR
#   - Enhanced monitoring + Performance Insights
# ─────────────────────────────────────────────────────────────────

locals {
  common_tags = merge(var.tags, {
    Module    = "rds"
    ManagedBy = "terraform"
  })

  logical_replication_parameters = var.enable_logical_replication ? {
    rds_logical_replication = {
      name  = "rds.logical_replication"
      value = "1"
    }
    max_wal_senders = {
      name  = "max_wal_senders"
      value = var.logical_replication_max_wal_senders
    }
    max_replication_slots = {
      name  = "max_replication_slots"
      value = var.logical_replication_max_replication_slots
    }
  } : {}
}

# ─── KMS key cho RDS ──────────────────────────────────────────────
resource "aws_kms_key" "rds" {
  description             = "KMS key cho RDS ${var.identifier}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.identifier}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ─── DB Subnet Group ──────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

# ─── Parameter Group: force SSL + log slow queries ────────────────
resource "aws_db_parameter_group" "main" {
  name   = "${var.identifier}-pg"
  family = var.parameter_group_family

  # Force SSL/TLS connection
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }

  # Log slow queries (>1s)
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  dynamic "parameter" {
    for_each = local.logical_replication_parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = "pending-reboot"
    }
  }

  tags = local.common_tags
}

# ─── IAM role cho Enhanced Monitoring ─────────────────────────────
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.identifier}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ─── RDS Instance ─────────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier = var.identifier

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.master_username
  password = var.master_password
  port     = 5432

  multi_az               = true # ★ HA — synchronous standby ở AZ khác
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids
  parameter_group_name   = aws_db_parameter_group.main.name

  # Backup
  backup_retention_period  = var.backup_retention_days
  backup_window            = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot    = true
  delete_automated_backups = false

  # Snapshot khi destroy (an toàn)
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  deletion_protection = var.deletion_protection

  # Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  performance_insights_retention_period = 7

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Auto minor version upgrade trong maintenance window
  auto_minor_version_upgrade = true

  # IAM database authentication (cho IRSA-style DB auth — optional)
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  apply_immediately = var.apply_immediately

  tags = merge(local.common_tags, {
    Name = var.identifier
  })

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier, # timestamp() đổi mỗi plan
      password,                  # password đổi qua Secrets Manager rotation
    ]
  }
}
