variable "cloud_name" {
  description = "Optional clouds.yaml profile name. Leave null to use OS_* environment variables."
  type        = string
  default     = null
}

variable "external_network_name" {
  description = "Neutron external network name used for router gateway and floating IPs."
  type        = string
  default     = "public"
}

variable "tenant_network_name" {
  description = "Tenant network name."
  type        = string
  default     = "voting-tenant-net"
}

variable "tenant_subnet_name" {
  description = "Tenant subnet name."
  type        = string
  default     = "voting-tenant-subnet"
}

variable "tenant_network_cidr" {
  description = "Tenant network CIDR."
  type        = string
  default     = "10.42.0.0/24"
}

variable "dns_nameservers" {
  description = "DNS resolvers assigned to the tenant subnet."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "router_name" {
  description = "Neutron router name."
  type        = string
  default     = "voting-router"
}

variable "image_name" {
  description = "Glance image name for the Harbor VM."
  type        = string
  default     = "ubuntu-22.04"
}

variable "harbor_flavor_name" {
  description = "Nova flavor for Harbor. Target shape is 2 vCPU and 3-4 GB RAM."
  type        = string
  default     = "m1.medium"
}

variable "availability_zone" {
  description = "Optional Nova availability zone."
  type        = string
  default     = null
}

variable "keypair_name" {
  description = "OpenStack keypair name."
  type        = string
  default     = "devsecops-voting"
}

variable "keypair_public_key" {
  description = "Public key content. If empty, keypair_public_key_path is used."
  type        = string
  default     = ""
}

variable "keypair_public_key_path" {
  description = "Path to an SSH public key file used when keypair_public_key is empty."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH, web, Kubernetes API, and lab ingress ports."
  type        = string
  default     = "0.0.0.0/0"
}

variable "harbor_instance_name" {
  description = "Harbor Nova instance name."
  type        = string
  default     = "harbor-registry"
}

variable "harbor_hostname" {
  description = "Expected Harbor hostname used for outputs and manual install."
  type        = string
  default     = "harbor.openstack.local"
}

variable "harbor_root_volume_size" {
  description = "Harbor boot volume size in GB."
  type        = number
  default     = 20
}

variable "harbor_data_volume_size" {
  description = "Harbor data volume size in GB."
  type        = number
  default     = 80
}
