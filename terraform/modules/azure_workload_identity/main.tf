# ─────────────────────────────────────────────────────────────────
# Azure Workload Identity Module — tương đương IRSA AWS
#
# Tạo:
#   - User Assigned Managed Identity
#   - Federated Identity Credential (trust AKS OIDC issuer)
#   - Optional Key Vault role assignment
#
# Caller gắn UAMI client_id vào ServiceAccount K8s qua annotation:
#   azure.workload.identity/client-id: <client_id>
# ─────────────────────────────────────────────────────────────────

locals {
  common_tags = merge(var.tags, {
    Module    = "azure_workload_identity"
    ManagedBy = "terraform"
  })
}

resource "azurerm_user_assigned_identity" "this" {
  name                = var.identity_name
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = local.common_tags
}

resource "azurerm_federated_identity_credential" "this" {
  name                = "${var.identity_name}-fed"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account}"
}

# ─── Optional: cấp quyền đọc Key Vault secret ─────────────────────
resource "azurerm_role_assignment" "kv_secrets_user" {
  count                = var.assign_key_vault_role ? 1 : 0
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}
