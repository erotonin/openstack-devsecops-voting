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

resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "${var.name_prefix}-github-actions"
  resource_group_name = module.azure_networking.resource_group_name
  location            = var.location

  tags = {
    ManagedBy = "terraform"
    Purpose   = "github-actions-oidc"
  }
}

resource "azurerm_federated_identity_credential" "github_actions_main" {
  name                = "${var.name_prefix}-github-main"
  resource_group_name = module.azure_networking.resource_group_name
  parent_id           = azurerm_user_assigned_identity.github_actions.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_repo}:ref:refs/heads/main"
}

resource "azurerm_role_assignment" "github_actions_acr_push" {
  principal_id                     = azurerm_user_assigned_identity.github_actions.principal_id
  role_definition_name             = "AcrPush"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
