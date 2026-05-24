variable "identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "engine_version" {
  description = "Postgres major.minor version"
  type        = string
  default     = "15.7"
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "postgres15"
}

variable "instance_class" {
  description = "RDS instance class (db.t4g.micro free tier eligible)"
  type        = string
  default     = "db.t4g.small"
}

variable "allocated_storage" {
  description = "Initial storage GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Auto-scale storage limit GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Database name (default db tạo sẵn)"
  type        = string
  default     = "voting"
}

variable "master_username" {
  description = "Master username"
  type        = string
  default     = "postgres"
}

variable "master_password" {
  description = "Master password (sinh từ random_password ở module secrets)"
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "DB subnet IDs (>=2 AZ)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS Multi-AZ yêu cầu DB subnet ở >=2 AZ"
  }
}

variable "security_group_ids" {
  description = "VPC SG IDs (RDS SG)"
  type        = list(string)
}

variable "backup_retention_days" {
  description = "Backup retention (1-35 days)"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot khi destroy (true cho dev, false cho prod)"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Bật deletion protection (true cho prod)"
  type        = bool
  default     = true
}

variable "iam_database_authentication_enabled" {
  description = "Bật IAM DB auth"
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply changes ngay (true cho dev, false cho prod để chờ maintenance window)"
  type        = bool
  default     = false
}

variable "enable_logical_replication" {
  description = "Enable RDS PostgreSQL logical replication parameters for cross-cloud publication."
  type        = bool
  default     = false
}

variable "logical_replication_max_wal_senders" {
  description = "max_wal_senders value when logical replication is enabled."
  type        = string
  default     = "10"
}

variable "logical_replication_max_replication_slots" {
  description = "max_replication_slots value when logical replication is enabled."
  type        = string
  default     = "10"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
