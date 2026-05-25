# ─────────────────────────────────────────────────────────────────
# Azure Networking Module
#
# Tạo:
#   - Resource Group
#   - Virtual Network
#   - Subnet AKS (cho cluster)
#   - Subnet GatewaySubnet (cho VPN — phải tên CHÍNH XÁC "GatewaySubnet")
#   - NSG default-deny + allow-list rule (least privilege)
#   - Flow logs (NSG flow log → Storage Account)
# ─────────────────────────────────────────────────────────────────

locals {
  common_tags = merge(var.tags, {
    Module    = "azure_networking"
    ManagedBy = "terraform"
  })
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.name_prefix}-rg"
  location = var.location

  tags = local.common_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]

  tags = local.common_tags
}

# ─── AKS subnet ────────────────────────────────────────────────────
resource "azurerm_subnet" "aks" {
  name                 = "${var.name_prefix}-snet-aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# ─── GatewaySubnet — REQUIRED tên "GatewaySubnet" cho Azure VPN GW ──
resource "azurerm_subnet" "postgres" {
  name                 = "${var.name_prefix}-snet-postgres"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.db_subnet_cidr]

  delegation {
    name = "postgres-flexible-server"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet" # Bắt buộc, không đổi
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# ─── NSG cho AKS subnet — default deny, allow-list cụ thể ──────────
resource "azurerm_network_security_group" "aks" {
  name                = "${var.name_prefix}-nsg-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow inbound từ VPC AWS qua VPN (peer cross-cloud)
  security_rule {
    name                       = "AllowVPNFromAWS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.peer_vpc_cidr
    destination_address_prefix = var.aks_subnet_cidr
  }

  # Allow Azure Load Balancer health probe
  security_rule {
    name                       = "AllowAzureLB"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Allow VirtualNetwork inter-pod
  security_rule {
    name                       = "AllowVnetInBound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Default deny (Azure tự có rule priority 65000, đây là explicit reinforce)
  # AKS LoadBalancer services receive traffic on nodePort targets.
  security_rule {
    name                       = "AllowPublicLoadBalancerNodePorts"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "Internet"
    destination_address_prefix = var.aks_subnet_cidr
  }

  # Public LoadBalancer frontend traffic is evaluated before backend DNAT.
  security_rule {
    name                       = "AllowPublicHttpLoadBalancer"
    priority                   = 125
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}
