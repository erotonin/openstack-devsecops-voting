resource "random_string" "acr_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_container_registry" "acr" {
  name                = "devsecopsvotingacr${random_string.acr_suffix.result}"
  resource_group_name = module.azure_networking.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

# Cấp quyền cho AKS được kéo Image từ ACR này
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = module.aks.kubelet_identity_object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
