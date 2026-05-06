terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
        helm = {
            source  = "hashicorp/helm"
            version = "~> 2.12"
        }
        kubernetes = {
            source  = "hashicorp/kubernetes"
            version = "~> 2.24"
        }
    }

    backend "s3" {
        bucket         = "devsecops-voting-tfstate-erotonin"
        key            = "aws/terraform.tfstate"
        region         = "us-east-1"
        dynamodb_table = "devsecops-voting-terraform-locks"
        encrypt        = true
    }
}

provider "aws" {
    region = var.aws_region
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    command     = "aws"
  }
}
