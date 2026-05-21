variable "name_prefix" {
  description = "Prefix tên resource (vd: devsecops-voting)"
  type        = string
  default     = "devsecops-voting"
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_cidr" {
  description = "CIDR cho VNet"
  type        = string
}

variable "aks_subnet_cidr" {
  description = "CIDR cho AKS subnet"
  type        = string
}

variable "gateway_subnet_cidr" {
  description = "CIDR cho GatewaySubnet (VPN). Phải /27 hoặc lớn hơn."
  type        = string
  default     = "10.1.255.0/27"
}

variable "peer_vpc_cidr" {
  description = "CIDR của VPC AWS (peer qua VPN). Cho phép inbound từ AWS."
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
