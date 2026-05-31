resource "random_string" "acr_suffix" {
  length  = 6
  special = false
  upper   = false
}

#checkov:skip=CKV_AZURE_139:Public access is intentionally kept for GitHub-hosted runners and AKS pulls in the student demo; production should use private endpoints.
#checkov:skip=CKV_AZURE_163:ACR vulnerability scanning requires Defender/Premium capabilities that are outside the cost-capped demo scope; CI performs Trivy image scans.
#checkov:skip=CKV_AZURE_164:Trusted image enforcement is implemented with Cosign and Sigstore policy-controller on Kubernetes admission.
#checkov:skip=CKV_AZURE_165:ACR geo-replication requires Premium; this project demonstrates multi-cloud DR through AKS warm standby and GitOps.
#checkov:skip=CKV_AZURE_166:Image quarantine/verification is represented by CI Trivy/Cosign and Kubernetes admission policy instead of ACR Premium quarantine.
#checkov:skip=CKV_AZURE_167:Retention cleanup is intentionally handled by small demo repositories and lifecycle discipline; Premium ACR retention is a production follow-up.
#checkov:skip=CKV_AZURE_237:Dedicated data endpoints require Premium/private networking and are out of scope for this cost-capped student demo.
#checkov:skip=CKV_AZURE_233:Zone redundant ACR requires Premium and is documented as a production hardening item.
resource "azurerm_container_registry" "acr" {
  name                = "devsecopsvotingacr${random_string.acr_suffix.result}"
  resource_group_name = module.azure_networking.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

# Grant AKS permission to pull images from this ACR.
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

resource "azurerm_federated_identity_credential" "github_actions_dev" {
  name                = "${var.name_prefix}-github-dev"
  resource_group_name = module.azure_networking.resource_group_name
  parent_id           = azurerm_user_assigned_identity.github_actions.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_repo}:ref:refs/heads/dev"
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
