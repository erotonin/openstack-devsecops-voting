# ─────────────────────────────────────────────────────────────────
# AKS Module — DR warm standby (cho Active-Passive narrative)
#
# Cluster nhỏ, autoscale 1-5, không có app workload bình thường.
# Khi DR drill: scale up + Velero restore + ESO sync secret.
# ─────────────────────────────────────────────────────────────────

locals {
  common_tags = merge(var.tags, {
    Module    = "aks"
    Cluster   = var.cluster_name
    ManagedBy = "terraform"
  })
}

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "${var.cluster_name}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  # ── Workload Identity (tương đương IRSA AWS) ──
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # ── Private cluster: API server không expose public ──
  # private_cluster_enabled = true (bật khi prod, tắt cho dev cho dễ kubectl)

  default_node_pool {
    name                = "system"
    vm_size             = var.vm_size
    vnet_subnet_id      = var.subnet_id
    enable_auto_scaling = true
    min_count           = var.node_min_count
    max_count           = var.node_max_count
    os_disk_size_gb     = 50
    os_disk_type        = "Managed"
    type                = "VirtualMachineScaleSets"

    # System node pool only — taint để app pod không schedule lên đây
    only_critical_addons_enabled = true

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico" # cho NetworkPolicy
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
  }

  # ── Defender for Cloud (threat intel) ──
  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
  }

  # Azure Policy add-on (tương đương OPA Gatekeeper trong AWS phía AKS)
  azure_policy_enabled = true

  tags = local.common_tags
}

# ── User node pool cho workload (auto-scale) ──
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.user_vm_size
  vnet_subnet_id        = var.subnet_id
  enable_auto_scaling   = true
  min_count             = var.user_min_count
  max_count             = var.user_max_count
  os_disk_size_gb       = 50
  mode                  = "User"

  upgrade_settings {
    max_surge = "33%"
  }

  tags = local.common_tags
}
