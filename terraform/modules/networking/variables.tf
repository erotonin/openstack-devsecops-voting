variable "name_prefix" {
  description = "Prefix for resource names (vd: devsecops-voting)"
  type        = string
  default     = "devsecops"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block"
  }
}

variable "public_subnets" {
  description = "Public subnet CIDRs (1 per AZ)"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs (1 per AZ) — for EKS workload"
  type        = list(string)
}

variable "database_subnets" {
  description = "DB subnet CIDRs (1 per AZ) — RDS, isolated, no internet route"
  type        = list(string)
  default     = []
}

variable "azs" {
  description = "Availability Zones (>= 2 for HA)"
  type        = list(string)
  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least 2 AZs required for HA"
  }
}

variable "cluster_name" {
  description = "EKS cluster name (used for subnet tagging — required by AWS Load Balancer Controller)"
  type        = string
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "CloudWatch log retention for VPC Flow Logs"
  type        = number
  default     = 30
}

variable "flow_logs_kms_key_arn" {
  description = "KMS key ARN to encrypt flow logs (optional, AWS managed key if null)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
