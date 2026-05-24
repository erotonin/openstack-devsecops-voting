locals {
  azure_postgres_enabled      = var.enable_azure_postgres_standby
  azure_postgres_server_name  = substr(replace("${var.name_prefix}-pg-standby", "-", ""), 0, 63)
  azure_db_host_effective     = local.azure_postgres_enabled ? azurerm_postgresql_flexible_server.standby[0].fqdn : var.azure_db_host
  azure_db_user_effective     = local.azure_postgres_enabled ? "pgadminuser" : "postgres"
  azure_db_password_effective = random_password.azure_db_password.result
  azure_db_database_effective = "voting"
  azure_db_ssl_mode_effective = "Require"
}

resource "azurerm_private_dns_zone" "postgres" {
  count               = local.azure_postgres_enabled ? 1 : 0
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = module.azure_networking.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count                 = local.azure_postgres_enabled ? 1 : 0
  name                  = "${var.name_prefix}-postgres-dns-link"
  resource_group_name   = module.azure_networking.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = module.azure_networking.vnet_id
}

resource "azurerm_postgresql_flexible_server" "standby" {
  count                  = local.azure_postgres_enabled ? 1 : 0
  name                   = local.azure_postgres_server_name
  resource_group_name    = module.azure_networking.resource_group_name
  location               = var.location
  version                = "15"
  delegated_subnet_id    = module.azure_networking.postgres_subnet_id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres[0].id
  administrator_login    = local.azure_db_user_effective
  administrator_password = local.azure_db_password_effective
  sku_name               = var.azure_postgres_sku_name
  storage_mb             = var.azure_postgres_storage_mb
  backup_retention_days  = 7
  public_network_access_enabled = false
  zone                   = "1"

  authentication {
    password_auth_enabled = true
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "voting" {
  count     = local.azure_postgres_enabled ? 1 : 0
  name      = local.azure_db_database_effective
  server_id = azurerm_postgresql_flexible_server.standby[0].id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

resource "azurerm_postgresql_flexible_server_configuration" "wal_level" {
  count     = local.azure_postgres_enabled ? 1 : 0
  name      = "wal_level"
  server_id = azurerm_postgresql_flexible_server.standby[0].id
  value     = "logical"
}
