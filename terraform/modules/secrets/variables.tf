variable "name" {
  description = "Tên secret (vd: voting-db-credentials)"
  type        = string
}

variable "description" {
  description = "Mô tả"
  type        = string
  default     = ""
}

variable "secret_data" {
  description = "Map dữ liệu secret (key-value)"
  type        = map(string)
  default     = {}
}

variable "generate_password" {
  description = "Tự sinh password và merge vào secret_data với key `password`"
  type        = bool
  default     = true
}

variable "recovery_window_in_days" {
  description = "Recovery window khi delete (0 = xoá ngay, 7-30 = giữ recover được)"
  type        = number
  default     = 7
}

variable "allowed_principals" {
  description = "List ARN principal được phép GetSecretValue"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
