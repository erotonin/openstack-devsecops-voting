data "openstack_networking_network_v2" "external" {
  name = var.external_network_name
}

resource "openstack_networking_network_v2" "tenant" {
  name           = var.tenant_network_name
  admin_state_up = true
}

resource "openstack_networking_subnet_v2" "tenant" {
  name            = var.tenant_subnet_name
  network_id      = openstack_networking_network_v2.tenant.id
  cidr            = var.tenant_network_cidr
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_router_v2" "tenant" {
  name                = var.router_name
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

resource "openstack_networking_router_interface_v2" "tenant" {
  router_id = openstack_networking_router_v2.tenant.id
  subnet_id = openstack_networking_subnet_v2.tenant.id
}
