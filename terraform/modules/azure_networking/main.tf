resource "azurerm_resource_group" "rg" {
  name     = "rg-devsecops-voting-aks"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-devsecops-voting"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]
}
