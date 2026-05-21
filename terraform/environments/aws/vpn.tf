resource "aws_customer_gateway" "cgw" {
  bgp_asn    = var.azure_bgp_asn
  ip_address = data.terraform_remote_state.azure.outputs.azure_vpn_public_ip
  type       = "ipsec.1"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-azure-cgw"
  })
}

resource "aws_vpn_gateway" "vgw" {
  vpc_id = module.networking.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vgw"
  })
}

resource "aws_vpn_connection" "vpn" {
  vpn_gateway_id      = aws_vpn_gateway.vgw.id
  customer_gateway_id = aws_customer_gateway.cgw.id
  type                = "ipsec.1"
  static_routes_only  = false

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-aws-azure-bgp"
  })
}

resource "aws_vpn_gateway_route_propagation" "private" {
  count          = length(module.networking.private_route_table_ids)
  vpn_gateway_id = aws_vpn_gateway.vgw.id
  route_table_id = module.networking.private_route_table_ids[count.index]
}

