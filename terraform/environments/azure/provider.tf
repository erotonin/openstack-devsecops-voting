terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Cấu hình "Móc" vào ổ cứng Azure ta đã tạo ban nãy
  backend "azurerm" {
    resource_group_name  = "rg-devsecops-voting-tfstate"
    storage_account_name = "stdevsecopstferotonin"
    container_name       = "tfstate"
    key                  = "azure/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "kubernetes" {
  host                   = var.bootstrap_provider_mode ? "https://127.0.0.1" : module.aks.host
  client_certificate     = var.bootstrap_provider_mode ? "" : base64decode(module.aks.client_certificate)
  client_key             = var.bootstrap_provider_mode ? "" : base64decode(module.aks.client_key)
  cluster_ca_certificate = var.bootstrap_provider_mode ? "" : base64decode(module.aks.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.bootstrap_provider_mode ? "https://127.0.0.1" : module.aks.host
    client_certificate     = var.bootstrap_provider_mode ? "" : base64decode(module.aks.client_certificate)
    client_key             = var.bootstrap_provider_mode ? "" : base64decode(module.aks.client_key)
    cluster_ca_certificate = var.bootstrap_provider_mode ? "" : base64decode(module.aks.cluster_ca_certificate)
  }
}
