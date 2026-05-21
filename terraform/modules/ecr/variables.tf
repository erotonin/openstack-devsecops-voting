variable "repo_names" {
  description = "List of ECR repository names"
  type        = list(string)
}

variable "force_delete" {
  description = "Allow Terraform to delete non-empty repositories. Keep false for production-like behavior."
  type        = bool
  default     = false
}

variable "max_image_count" {
  description = "Maximum number of images kept per repository"
  type        = number
  default     = 10
}
