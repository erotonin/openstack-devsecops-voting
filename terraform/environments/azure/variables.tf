variable "location" {
  default = "southeastasia"
}

variable "cluster_name" {
  default = "devsecops-voting-aks"
}

variable "gitops_repo_url" {
  default     = "https://github.com/erotonin/devsecops-voting.git"
  description = "Git repository URL used by the standby ArgoCD controller"
}

variable "gitops_target_revision" {
  default     = "main"
  description = "Git revision tracked by the standby ArgoCD controller"
}

variable "vnet_cidr" {
  description = "Azure VNet CIDR. Must not overlap with the AWS VPC CIDR."
  default     = "10.1.0.0/16"
}

variable "aks_subnet_cidr" {
  default = "10.1.1.0/24"
}

variable "gateway_subnet_cidr" {
  default = "10.1.255.0/27"
}

variable "aws_vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "name_prefix" {
  default = "devsecops-voting"
}

variable "azure_db_host" {
  description = "Azure PostgreSQL host after DR restore. Override this during the DR drill."
  default     = "restore-required.postgres.database.azure.com"
}

variable "azure_redis_host" {
  description = "Azure Redis host after DR restore. Override this during the DR drill."
  default     = "restore-required.redis.cache.windows.net"
}

variable "azure_bgp_asn" {
  default = 65000
}

variable "aws_bgp_asn" {
  default = 64512
}
