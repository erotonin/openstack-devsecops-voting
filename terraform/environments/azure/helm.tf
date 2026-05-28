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

resource "kubernetes_namespace" "voting_production" {
  metadata {
    name = "voting-production"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }

  depends_on = [module.aks]
}

locals {
  argocd_rbac_policy = join("\n", concat(
    [for group in var.argocd_sso_admin_groups : "g, ${group}, role:admin"],
    [for group in var.argocd_sso_readonly_groups : "g, ${group}, role:readonly"]
  ))

  argocd_cm = merge(
    {
      "admin.enabled" = "true"
    },
    var.argocd_sso_enabled ? {
      url = var.argocd_url
      "oidc.config" = yamlencode({
        name            = "Azure Entra ID"
        issuer          = "https://login.microsoftonline.com/${var.argocd_sso_tenant_id}/v2.0"
        clientID        = var.argocd_sso_client_id
        clientSecret    = "$oidc.azure.clientSecret"
        requestedScopes = ["openid", "profile", "email"]
        requestedIDTokenClaims = {
          groups = {
            essential = true
          }
        }
      })
    } : {}
  )

  argocd_secret_extra = var.argocd_sso_enabled ? {
    "oidc.azure.clientSecret" = var.argocd_sso_client_secret
  } : {}
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
        cm = local.argocd_cm
        params = {
          "server.insecure" = var.argocd_sso_enabled ? "true" : "false"
        }
        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv"     = local.argocd_rbac_policy
        }
        secret = {
          extra = local.argocd_secret_extra
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
          namespace = "voting-production"
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
      name      = "voting-azure-production"
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
        namespace = "voting-production"
      }
      ignoreDifferences = [
        {
          group        = "apps"
          kind         = "Deployment"
          jsonPointers = ["/spec/replicas"]
        }
      ]
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
    kubernetes_namespace.voting_production,
  ]
}

resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  namespace        = "kyverno"
  create_namespace = true
  version          = "3.1.4" # stable version
}
