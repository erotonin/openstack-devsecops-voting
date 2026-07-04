locals {
  public_key_material = var.keypair_public_key != "" ? var.keypair_public_key : file(var.keypair_public_key_path)
}

resource "openstack_compute_keypair_v2" "deployer" {
  name       = var.keypair_name
  public_key = local.public_key_material
}
