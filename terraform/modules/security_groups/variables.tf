variable "name_prefix" {
  description = "Prefix tên SG"
  type        = string
  default     = "devsecops"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR (cho ALB egress)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (cho tag SG)"
  type        = string
}

variable "eks_pod_cidrs" {
  description = "List CIDR của EKS private subnet (nguồn pod)"
  type        = list(string)
}

variable "peer_vpc_cidrs" {
  description = "List CIDR của Azure VNet (cho VPN peer)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
