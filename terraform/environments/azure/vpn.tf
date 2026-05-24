resource "azurerm_public_ip" "vpn_ip" {
  name                = "pip-vpn-devsecops"
  location            = var.location
  resource_group_name = module.azure_networking.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_virtual_network_gateway" "vng" {
  name                = "vng-devsecops-voting"
  location            = var.location
  resource_group_name = module.azure_networking.resource_group_name

  type       = "Vpn"
  vpn_type   = "RouteBased"
  sku        = "VpnGw1AZ"
  enable_bgp = true

  bgp_settings {
    asn = var.azure_bgp_asn
    peering_addresses {
      ip_configuration_name = "vnetGatewayConfig"
      apipa_addresses       = [local.aws_tunnel1_cgw_inside_address]
    }
  }

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = module.azure_networking.gateway_subnet_id
  }
}

output "azure_vpn_public_ip" {
  value = azurerm_public_ip.vpn_ip.ip_address
}

data "terraform_remote_state" "aws" {
  backend = "s3"
  config = {
    bucket = "devsecops-voting-tfstate-erotonin"
    key    = "aws/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  # During full destroy the AWS state can be emptied before Azure refreshes.
  # Keep placeholder values so Azure VPN resources remain destroyable.
  aws_tunnel1_ip                 = try(data.terraform_remote_state.aws.outputs.aws_tunnel1_ip, "203.0.113.1")
  aws_tunnel1_vgw_inside_address = try(data.terraform_remote_state.aws.outputs.aws_tunnel1_vgw_inside_address, "169.254.21.97")
  # cgw_inside_address is AZURE's BGP IP inside the tunnel (not AWS's)
  aws_tunnel1_cgw_inside_address = try(data.terraform_remote_state.aws.outputs.aws_tunnel1_cgw_inside_address, "169.254.21.98")
  aws_tunnel1_preshared_key      = try(data.terraform_remote_state.aws.outputs.aws_tunnel1_preshared_key, "destroy-placeholder-shared-key")
}

resource "azurerm_local_network_gateway" "lng" {
  name                = "lng-aws"
  resource_group_name = module.azure_networking.resource_group_name
  location            = var.location
  gateway_address     = local.aws_tunnel1_ip
  address_space       = [var.aws_vpc_cidr]

  bgp_settings {
    asn                 = var.aws_bgp_asn
    bgp_peering_address = local.aws_tunnel1_vgw_inside_address
  }
}

resource "azurerm_virtual_network_gateway_connection" "vpn_conn" {
  name                = "conn-azure-to-aws"
  location            = var.location
  resource_group_name = module.azure_networking.resource_group_name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.lng.id
  shared_key                 = local.aws_tunnel1_preshared_key
  enable_bgp                 = true

  custom_bgp_addresses {
    primary = local.aws_tunnel1_cgw_inside_address
  }
}
