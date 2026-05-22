variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "subnet_ids" {
  description = "Private subnet IDs cho EKS (cluster + node group)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS yêu cầu ít nhất 2 subnet ở 2 AZ"
  }
}

variable "endpoint_public_access" {
  description = "EKS API public hay private only"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR cho phép access public endpoint EKS API (0.0.0.0/0 cho dev, scoped cho prod)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "List EC2 instance type (multi-type giúp Spot không out-of-capacity)"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Max node count"
  type        = number
  default     = 6
}

variable "node_min_size" {
  description = "Min node count (>=2 cho HA)"
  type        = number
  default     = 2

  validation {
    condition     = var.node_min_size >= 2
    error_message = "node_min_size phải >= 2 cho HA (PDB minAvailable=1 cần >=2 node)"
  }
}

variable "node_disk_size" {
  description = "EBS volume size (GB) per node"
  type        = number
  default     = 50
}

variable "capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "log_retention_days" {
  description = "CloudWatch retention cho EKS control plane log"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
