# 1. Gọi module mạng ảo
module "azure_networking" {
  source      = "../../modules/azure_networking"
  location    = var.location
  vnet_cidr   = var.vnet_cidr
  subnet_cidr = var.subnet_cidr
}

# 2. Gọi module tạo cụm AKS
module "aks" {
  source       = "../../modules/aks"
  cluster_name = var.cluster_name
  location     = var.location
  rg_name      = module.azure_networking.rg_name
  subnet_id    = module.azure_networking.subnet_id
}
