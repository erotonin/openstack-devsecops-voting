data "terraform_remote_state" "azure" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-devsecops-voting-tfstate"
    storage_account_name = "stdevsecopstferotonin"
    container_name       = "tfstate"
    key                  = "azure/terraform.tfstate"
  }
}

resource "kubernetes_secret" "aks_cluster" {
  metadata {
    name      = "devsecops-voting-aks-secret"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }

  type = "Opaque"

  data = {
    name   = "devsecops-voting-aks"
    server = data.terraform_remote_state.azure.outputs.aks_host
    config = jsonencode({
      tlsClientConfig = {
        insecure = false
        caData   = data.terraform_remote_state.azure.outputs.aks_cluster_ca_certificate
        certData = data.terraform_remote_state.azure.outputs.aks_client_certificate
        keyData  = data.terraform_remote_state.azure.outputs.aks_client_key
      }
    })
  }

  depends_on = [helm_release.argocd]
}
