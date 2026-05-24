variable "name" {
  description = "Replication group name"
  type        = string
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t4g.micro"
}

variable "parameter_group_name" {
  description = "Redis parameter group"
  type        = string
  default     = "default.redis7"
}

variable "subnet_ids" {
  description = "Private subnet IDs for Redis"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for Redis"
  type        = list(string)
}

variable "auth_token" {
  description = "Redis auth token"
  type        = string
  sensitive   = true
}

variable "num_cache_clusters" {
  description = "Number of cache nodes"
  type        = number
  default     = 2
}

variable "log_group_name" {
  description = "CloudWatch log group name for Redis slow logs"
  type        = string
}

variable "apply_immediately" {
  description = "Apply Redis changes immediately"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
