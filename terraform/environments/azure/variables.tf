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

variable "subnet_cidr" {
  default = "10.1.1.0/24"
}
