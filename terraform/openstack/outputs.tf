output "harbor_private_ip" {
  description = "Harbor fixed IP on the tenant network."
  value       = openstack_networking_port_v2.harbor.all_fixed_ips[0]
}

output "harbor_floating_ip" {
  description = "Harbor floating IP."
  value       = openstack_networking_floatingip_v2.harbor.address
}

output "harbor_url" {
  description = "Harbor lab URL."
  value       = "http://${openstack_networking_floatingip_v2.harbor.address}"
}

output "harbor_hostname" {
  description = "Expected Harbor hostname."
  value       = var.harbor_hostname
}

output "tenant_network_id" {
  description = "Tenant network ID."
  value       = openstack_networking_network_v2.tenant.id
}

output "subnet_id" {
  description = "Tenant subnet ID."
  value       = openstack_networking_subnet_v2.tenant.id
}

output "router_id" {
  description = "Router ID."
  value       = openstack_networking_router_v2.tenant.id
}

output "security_group_ids" {
  description = "Security groups created for the lab."
  value = {
    ssh            = openstack_networking_secgroup_v2.ssh.id
    harbor_web     = openstack_networking_secgroup_v2.harbor_web.id
    kubernetes_api = openstack_networking_secgroup_v2.kubernetes_api.id
    node_ingress   = openstack_networking_secgroup_v2.node_ingress.id
    icmp           = openstack_networking_secgroup_v2.icmp.id
  }
}
