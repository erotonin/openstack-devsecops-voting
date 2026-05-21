variable "location" {
  default = "southeastasia"
}

variable "cluster_name" {
  default = "devsecops-voting-aks"
}

variable "vnet_cidr" {
  description = "Dải IP VNet không được trùng với AWS VPC"
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
  default = "postgres-restore-placeholder.postgres.database.azure.com"
}

variable "azure_redis_host" {
  default = "redis-restore-placeholder.redis.cache.windows.net"
}

variable "azure_bgp_asn" {
  default = 65000
}

variable "aws_bgp_asn" {
  default = 64512
}
