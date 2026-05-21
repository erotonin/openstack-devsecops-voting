resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "0.10.5"

  values = [
    yamlencode({
      installCRDs = true
      podLabels = {
        "azure.workload.identity/use" = "true"
      }
      serviceAccount = {
        create = true
        name   = "external-secrets"
        annotations = {
          "azure.workload.identity/client-id" = module.external_secrets_workload_identity.client_id
        }
      }
    })
  ]

  depends_on = [
    module.aks,
    module.external_secrets_workload_identity,
  ]
}

resource "kubernetes_manifest" "azure_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "azure-key-vault"
    }
    spec = {
      provider = {
        azurekv = {
          authType = "WorkloadIdentity"
          vaultUrl = azurerm_key_vault.app.vault_uri
          serviceAccountRef = {
            name      = "external-secrets"
            namespace = "external-secrets"
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

