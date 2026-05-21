terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
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
  features {}
}
