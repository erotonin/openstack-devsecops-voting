output "aks_host" {
  value     = module.aks.host
  sensitive = true
}

output "resource_group_name" {
  value = module.azure_networking.resource_group_name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "vnet_id" {
  value = module.azure_networking.vnet_id
}

output "gateway_subnet_id" {
  value = module.azure_networking.gateway_subnet_id
}

output "acr_login_server_from_module" {
  value = azurerm_container_registry.acr.login_server
}

output "github_actions_azure_client_id" {
  value       = azurerm_user_assigned_identity.github_actions.client_id
  description = "Azure workload identity client ID for GitHub Actions OIDC"
}

output "key_vault_uri" {
  value = azurerm_key_vault.app.vault_uri
}

output "app_runtime_secret_name" {
  value = azurerm_key_vault_secret.app_runtime.name
}

output "azure_bgp_asn" {
  value = var.azure_bgp_asn
}
output "aks_client_certificate" {
  value     = module.aks.client_certificate
  sensitive = true
}
output "aks_client_key" {
  value     = module.aks.client_key
  sensitive = true
}
output "aks_cluster_ca_certificate" {
  value     = module.aks.cluster_ca_certificate
  sensitive = true
}
