# 1. Gọi module mạng ảo
module "azure_networking" {
  source              = "../../modules/azure_networking"
  location            = var.location
  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
  db_subnet_cidr      = var.db_subnet_cidr
  gateway_subnet_cidr = var.gateway_subnet_cidr
  peer_vpc_cidr       = var.aws_vpc_cidr
}

# 2. Gọi module tạo cụm AKS
module "aks" {
  source                = "../../modules/aks"
  cluster_name          = var.cluster_name
  location              = var.location
  resource_group_name   = module.azure_networking.resource_group_name
  subnet_id             = module.azure_networking.aks_subnet_id
  enable_user_node_pool = true
  user_vm_size          = "Standard_B2s_v2"
}
