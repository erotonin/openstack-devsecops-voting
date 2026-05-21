resource "kubernetes_namespace" "voting" {
  metadata {
    name = "voting"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }

  depends_on = [module.aks]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.16"

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        replicas = 1
        ingress = {
          enabled = false
        }
      }
      controller = {
        replicas = 1
      }
      repoServer = {
        replicas = 1
      }
      applicationSet = {
        replicas = 1
      }
      configs = {
        cm = {
          "admin.enabled" = "true"
        }
        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv"     = "g, devsecops-admins, role:admin\ng, devsecops-developers, role:readonly"
        }
      }
    })
  ]

  depends_on = [module.aks]
}

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

resource "kubernetes_manifest" "argocd_project_voting" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "voting"
      namespace = "argocd"
    }
    spec = {
      description = "Azure warm standby voting project"
      sourceRepos = [
        var.gitops_repo_url
      ]
      destinations = [
        {
          namespace = "voting"
          server    = "https://kubernetes.default.svc"
        }
      ]
      namespaceResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]
    }
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "argocd_app_azure" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "voting-azure"
      namespace = "argocd"
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "voting"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = "k8s"
        helm = {
          valueFiles = ["values-azure.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "voting"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_manifest.argocd_project_voting,
    kubernetes_manifest.azure_secret_store,
    kubernetes_namespace.voting,
  ]
}
