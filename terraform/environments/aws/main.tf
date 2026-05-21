module "networking" {
  source           = "../../modules/networking"
  vpc_cidr         = var.vpc_cidr
  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets
  cluster_name     = var.cluster_name
  azs              = ["${var.aws_region}a", "${var.aws_region}b"]
}

module "eks" {
  source              = "../../modules/eks"
  cluster_name        = var.cluster_name
  subnet_ids          = module.networking.private_subnet_ids
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  node_min_size       = var.node_min_size
}

module "ecr" {
  source     = "../../modules/ecr"
  repo_names = var.ecr_repo_names
}
