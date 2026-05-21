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
