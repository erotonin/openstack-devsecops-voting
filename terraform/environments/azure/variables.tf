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

variable "argocd_url" {
  type        = string
  default     = "https://argocd.local"
  description = "Canonical ArgoCD URL used for SSO callbacks"
}

variable "argocd_sso_enabled" {
  type        = bool
  default     = false
  description = "Enable ArgoCD OIDC SSO with Azure Entra ID"
}

variable "argocd_sso_tenant_id" {
  type        = string
  default     = ""
  description = "Azure Entra ID tenant ID for ArgoCD OIDC SSO"
}

variable "argocd_sso_client_id" {
  type        = string
  default     = ""
  description = "Azure Entra ID application client ID for ArgoCD OIDC SSO"
}

variable "argocd_sso_client_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Azure Entra ID application client secret for ArgoCD OIDC SSO"
}

variable "argocd_sso_admin_groups" {
  type        = list(string)
  default     = ["devsecops-admins"]
  description = "OIDC group names or object IDs mapped to ArgoCD admin"
}

variable "argocd_sso_readonly_groups" {
  type        = list(string)
  default     = ["devsecops-developers"]
  description = "OIDC group names or object IDs mapped to ArgoCD readonly"
}

variable "github_repo" {
  default     = "erotonin/devsecops-voting"
  description = "GitHub repository allowed to use Azure workload identity from GitHub Actions"
}

variable "vnet_cidr" {
  description = "Azure VNet CIDR. Must not overlap with the AWS VPC CIDR."
  default     = "10.1.0.0/16"
}

variable "aks_subnet_cidr" {
  default = "10.1.1.0/24"
}

variable "db_subnet_cidr" {
  description = "Azure PostgreSQL Flexible Server delegated subnet CIDR."
  default     = "10.1.2.0/24"
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

variable "enable_azure_postgres_standby" {
  type        = bool
  default     = true
  description = "Create Azure PostgreSQL Flexible Server as the logical replication subscriber."
}

variable "azure_postgres_sku_name" {
  type        = string
  default     = "B_Standard_B1ms"
  description = "Azure PostgreSQL Flexible Server SKU for the warm standby database."
}

variable "azure_postgres_storage_mb" {
  type        = number
  default     = 32768
  description = "Azure PostgreSQL storage size in MB."
}

variable "azure_redis_host" {
  description = "Redis host used by the Azure warm standby app. Defaults to the in-cluster Redis service to avoid extra Azure Redis cost."
  default     = "redis"
}

variable "azure_redis_password" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Redis password for Azure standby. Empty for the in-cluster Redis service."
}

variable "azure_redis_ssl" {
  type        = bool
  default     = false
  description = "Enable TLS for Azure standby Redis. False for the in-cluster Redis service."
}

variable "azure_bgp_asn" {
  default = 65000
}

variable "aws_bgp_asn" {
  default = 64512
}
