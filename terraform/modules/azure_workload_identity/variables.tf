variable "identity_name" {
  description = "User Assigned Managed Identity name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "RG để tạo UAMI"
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL"
  type        = string
}

variable "namespace" {
  description = "K8s namespace"
  type        = string
}

variable "service_account" {
  description = "K8s ServiceAccount"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID (optional). Nếu set, gán role 'Key Vault Secrets User'"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}

variable "assign_key_vault_role" {
  description = "Whether to assign Key Vault Secrets User. Keep this explicit so count never depends on computed IDs."
  type        = bool
  default     = false
}
