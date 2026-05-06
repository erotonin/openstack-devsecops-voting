# Cái này em sẽ tự gõ lúc chạy lệnh
variable "azure_vpn_ip" {
  description = "Địa chỉ IP của Azure VPN"
}

# Khai báo sự tồn tại của Azure cho AWS biết
resource "aws_customer_gateway" "cgw" {
  bgp_asn    = 65000
  ip_address = var.azure_vpn_ip
  type       = "ipsec.1"
}

# Dựng cổng vòm phía AWS
resource "aws_vpn_gateway" "vgw" {
  vpc_id = module.networking.vpc_id
}

# Nối ống nước từ Cổng AWS sang Cổng Azure
resource "aws_vpn_connection" "vpn" {
  vpn_gateway_id      = aws_vpn_gateway.vgw.id
  customer_gateway_id = aws_customer_gateway.cgw.id
  type                = "ipsec.1"
  static_routes_only  = true
}

# Chỉ đường: Ai muốn đi sang Azure (10.1.x.x) thì chui vào ống nước này
resource "aws_vpn_connection_route" "azure_route" {
  destination_cidr_block = "10.1.0.0/16"
  vpn_connection_id      = aws_vpn_connection.vpn.id
}

# Xin AWS thông số mật khẩu để mang về nhập cho Azure
output "aws_tunnel1_ip" {
  value = aws_vpn_connection.vpn.tunnel1_address
}
output "aws_tunnel1_preshared_key" {
  value     = aws_vpn_connection.vpn.tunnel1_preshared_key
  sensitive = true
}
