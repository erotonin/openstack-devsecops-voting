variable "role_name" {
  description = "IAM Role name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL (KHÔNG có https://)"
  type        = string
}

variable "namespace" {
  description = "K8s namespace của ServiceAccount"
  type        = string
}

variable "service_account" {
  description = "K8s ServiceAccount name"
  type        = string
}

variable "inline_policy_json" {
  description = "Inline IAM policy JSON document (optional)"
  type        = string
  default     = null
}

variable "create_inline_policy" {
  description = "Whether to create the inline policy. Keep this explicit so count never depends on computed policy JSON."
  type        = bool
  default     = false
}

variable "managed_policy_arns" {
  description = "List managed policy ARN attach"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
