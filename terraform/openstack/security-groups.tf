resource "openstack_networking_secgroup_v2" "ssh" {
  name        = "voting-ssh"
  description = "SSH access for lab administration"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.ssh.id
}

resource "openstack_networking_secgroup_v2" "harbor_web" {
  name        = "voting-harbor-web"
  description = "Harbor HTTP and HTTPS access"
}

resource "openstack_networking_secgroup_rule_v2" "harbor_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.harbor_web.id
}

resource "openstack_networking_secgroup_rule_v2" "harbor_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.harbor_web.id
}

resource "openstack_networking_secgroup_v2" "kubernetes_api" {
  name        = "voting-kubernetes-api"
  description = "Kubernetes API access for VM-based cluster fallback"
}

resource "openstack_networking_secgroup_rule_v2" "kubernetes_api_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.kubernetes_api.id
}

resource "openstack_networking_secgroup_v2" "node_ingress" {
  name        = "voting-node-ingress"
  description = "NodePort and ingress access for lab clusters"
}

resource "openstack_networking_secgroup_rule_v2" "nodeport_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.node_ingress.id
}

resource "openstack_networking_secgroup_rule_v2" "http_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.node_ingress.id
}

resource "openstack_networking_secgroup_rule_v2" "https_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.node_ingress.id
}

resource "openstack_networking_secgroup_v2" "icmp" {
  name        = "voting-icmp"
  description = "ICMP troubleshooting"
}

resource "openstack_networking_secgroup_rule_v2" "icmp_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.icmp.id
}
