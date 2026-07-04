data "openstack_images_image_v2" "harbor" {
  name        = var.image_name
  most_recent = true
}

resource "openstack_networking_port_v2" "harbor" {
  name           = "${var.harbor_instance_name}-port"
  network_id     = openstack_networking_network_v2.tenant.id
  admin_state_up = true

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.tenant.id
  }

  security_group_ids = [
    openstack_networking_secgroup_v2.ssh.id,
    openstack_networking_secgroup_v2.harbor_web.id,
    openstack_networking_secgroup_v2.icmp.id,
  ]
}

resource "openstack_compute_instance_v2" "harbor" {
  name              = var.harbor_instance_name
  flavor_name       = var.harbor_flavor_name
  key_pair          = openstack_compute_keypair_v2.deployer.name
  availability_zone = var.availability_zone
  user_data         = file("${path.module}/cloud-init/harbor.yaml")

  block_device {
    uuid                  = data.openstack_images_image_v2.harbor.id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.harbor_root_volume_size
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    port = openstack_networking_port_v2.harbor.id
  }

  depends_on = [
    openstack_networking_router_interface_v2.tenant,
  ]
}

resource "openstack_blockstorage_volume_v3" "harbor_data" {
  name = "${var.harbor_instance_name}-data"
  size = var.harbor_data_volume_size
}

resource "openstack_compute_volume_attach_v2" "harbor_data" {
  instance_id = openstack_compute_instance_v2.harbor.id
  volume_id   = openstack_blockstorage_volume_v3.harbor_data.id
  device      = "/dev/vdb"
}

resource "openstack_networking_floatingip_v2" "harbor" {
  pool = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "harbor" {
  floating_ip = openstack_networking_floatingip_v2.harbor.address
  port_id     = openstack_networking_port_v2.harbor.id
}
