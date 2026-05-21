variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group cho AKS"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID cho AKS"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "vm_size" {
  description = "VM size cho system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "node_min_count" {
  description = "Min count system node pool (>=1, warm standby)"
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Max count system node pool"
  type        = number
  default     = 3
}

variable "user_vm_size" {
  description = "VM size cho user node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_min_count" {
  description = "Min count user node pool (warm standby = 1)"
  type        = number
  default     = 1
}

variable "user_max_count" {
  description = "Max count user node pool (scale up khi DR)"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
