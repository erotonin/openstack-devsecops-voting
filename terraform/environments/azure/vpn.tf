resource "azurerm_public_ip" "vpn_ip" {
  name                = "pip-vpn-devsecops"
  location            = var.location
  resource_group_name = module.azure_networking.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

# Subnet đặc biệt bắt buộc phải mang tên "GatewaySubnet"
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet" 
  resource_group_name  = module.azure_networking.rg_name
  virtual_network_name = module.azure_networking.vnet_name
  address_prefixes     = ["10.1.255.0/27"]
}

# Cổng vòm VPN (Thứ sẽ tốn 45 phút để xây)
resource "azurerm_virtual_network_gateway" "vng" {
  name                = "vng-devsecops-voting"
  location            = var.location
  resource_group_name = module.azure_networking.rg_name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw1AZ"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }
}
output "azure_vpn_public_ip" {
  value = azurerm_public_ip.vpn_ip.ip_address
}
variable "aws_tunnel_ip" {
  description = "Địa chỉ IP Tunnel 1 của AWS"
}

variable "aws_preshared_key" {
  description = "Mật khẩu dùng chung giữa 2 đám mây"
  sensitive   = true
}

# Khai báo sự tồn tại của AWS (Local Network Gateway)
resource "azurerm_local_network_gateway" "lng" {
  name                = "lng-aws"
  resource_group_name = module.azure_networking.rg_name
  location            = var.location
  gateway_address     = var.aws_tunnel_ip
  address_space       = ["10.0.0.0/16"] # Dải IP của mạng AWS
}

# Chốt hạ: Cắm ống nước từ Azure sang AWS
resource "azurerm_virtual_network_gateway_connection" "vpn_conn" {
  name                = "conn-azure-to-aws"
  location            = var.location
  resource_group_name = module.azure_networking.rg_name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng.id

  shared_key = var.aws_preshared_key
}
