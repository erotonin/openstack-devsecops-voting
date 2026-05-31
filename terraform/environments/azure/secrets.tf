data "azurerm_client_config" "current" {}

resource "random_password" "azure_db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault" "app" { # nosemgrep: terraform.azure.security.keyvault.keyvault-specify-network-acl.keyvault-specify-network-acl - Network ACL is declared below; default allow is retained for External Secrets demo access until private endpoint/VPN is active.
  name                          = replace("${var.name_prefix}-kv", "-", "")
  location                      = var.location
  resource_group_name           = module.azure_networking.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }
}

resource "azurerm_role_assignment" "current_key_vault_admin" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_secret" "app_runtime" {
  name            = "voting-app-runtime"
  key_vault_id    = azurerm_key_vault.app.id
  content_type    = "application/json"
  expiration_date = "2099-12-31T23:59:59Z"
  value = jsonencode({
    REDIS_HOST                 = var.azure_redis_host
    REDIS_PORT                 = "6379"
    REDIS_PASSWORD             = var.azure_redis_password
    REDIS_SSL                  = tostring(var.azure_redis_ssl)
    DB_HOST                    = local.azure_db_host_effective
    DB_PORT                    = "5432"
    DB_USER                    = local.azure_db_user_effective
    DB_PASSWORD                = local.azure_db_password_effective
    DB_NAME                    = local.azure_db_database_effective
    DB_SSL                     = "true"
    DB_SSL_MODE                = local.azure_db_ssl_mode_effective
    DB_SSL_REJECT_UNAUTHORIZED = "false"
    DATABASE_URL               = "postgres://${local.azure_db_user_effective}:${urlencode(local.azure_db_password_effective)}@${local.azure_db_host_effective}:5432/${local.azure_db_database_effective}?sslmode=require"
    COOKIE_SECURE              = "false"
    COOKIE_SAMESITE            = "Lax"
  })

  depends_on = [azurerm_role_assignment.current_key_vault_admin]
}

module "external_secrets_workload_identity" {
  source                = "../../modules/azure_workload_identity"
  identity_name         = "${var.name_prefix}-eso"
  location              = var.location
  resource_group_name   = module.azure_networking.resource_group_name
  aks_oidc_issuer_url   = module.aks.oidc_issuer_url
  namespace             = "external-secrets"
  service_account       = "external-secrets"
  key_vault_id          = azurerm_key_vault.app.id
  assign_key_vault_role = true
}
