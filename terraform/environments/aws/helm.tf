resource "kubernetes_namespace" "voting" {
  metadata {
    name = "voting"
    labels = {
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }

  depends_on = [module.eks]
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
      global = {
        domain = var.argocd_domain
      }
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

  depends_on = [module.eks]
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
      serviceAccount = {
        create = true
        name   = "external-secrets"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.external_secrets_irsa.role_arn
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    module.external_secrets_irsa,
  ]
}

resource "kubernetes_manifest" "aws_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}

resource "helm_release" "gatekeeper" {
  name             = "gatekeeper"
  repository       = "https://open-policy-agent.github.io/gatekeeper/charts"
  chart            = "gatekeeper"
  namespace        = "gatekeeper-system"
  create_namespace = true
  version          = "3.17.1"

  values = [
    yamlencode({
      replicas = 1
      audit = {
        enabled = true
      }
    })
  ]

  depends_on = [module.eks]
}

resource "helm_release" "policy_controller" {
  count            = var.enable_image_signature_policy ? 1 : 0
  name             = "policy-controller"
  repository       = "https://sigstore.github.io/helm-charts"
  chart            = "policy-controller"
  namespace        = "cosign-system"
  create_namespace = true
  version          = "0.10.3"

  depends_on = [module.eks]
}

resource "helm_release" "kube_prometheus_stack" {
  count            = var.enable_observability ? 1 : 0
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "66.2.1"
  timeout          = 900

  values = [
    yamlencode({
      defaultRules = {
        create = false
      }
      kubeStateMetrics = {
        enabled = false
      }
      nodeExporter = {
        enabled = false
      }
      grafana = {
        service = {
          type = "ClusterIP"
        }
        sidecar = {
          dashboards = {
            enabled = true
            label   = "grafana_dashboard"
          }
        }
      }
      prometheus = {
        prometheusSpec = {
          retention                               = "15d"
          replicas                                = 1
          serviceMonitorSelectorNilUsesHelmValues = false
          ruleSelectorNilUsesHelmValues           = false
        }
      }
      alertmanager = {
        enabled = false
      }
      prometheusOperator = {
        admissionWebhooks = {
          enabled = false
        }
      }
    })
  ]

  depends_on = [module.eks]
}

resource "kubernetes_config_map" "grafana_voting_slo_dashboard" {
  count = var.enable_observability ? 1 : 0

  metadata {
    name      = "grafana-voting-slo-dashboard"
    namespace = "monitoring"
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "voting-slo.json" = file("${path.module}/../../../observability/grafana-dashboards/voting-slo.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "loki" {
  count            = var.enable_observability ? 1 : 0
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  namespace        = "logging"
  create_namespace = true
  version          = "6.23.0"
  timeout          = 600

  values = [
    yamlencode({
      deploymentMode = "SingleBinary"
      chunksCache = {
        enabled = false
      }
      resultsCache = {
        enabled = false
      }
      lokiCanary = {
        enabled = false
      }
      test = {
        enabled = false
      }
      loki = {
        auth_enabled  = false
        useTestSchema = true
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          type = "filesystem"
        }
      }
      singleBinary = {
        replicas = 1
        persistence = {
          enabled = false
        }
        extraVolumes = [
          {
            name     = "loki-data"
            emptyDir = {}
          }
        ]
        extraVolumeMounts = [
          {
            name      = "loki-data"
            mountPath = "/var/loki"
          }
        ]
      }
      read = {
        replicas = 0
      }
      write = {
        replicas = 0
      }
      backend = {
        replicas = 0
      }
    })
  ]

  depends_on = [module.eks]
}

resource "helm_release" "promtail" {
  count            = var.enable_observability ? 1 : 0
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  namespace        = "logging"
  create_namespace = true
  version          = "6.16.6"

  values = [
    yamlencode({
      config = {
        clients = [
          {
            url = "http://loki-gateway.logging.svc.cluster.local/loki/api/v1/push"
          }
        ]
      }
    })
  ]

  depends_on = [helm_release.loki]
}

resource "helm_release" "falco" {
  count            = var.enable_runtime_security ? 1 : 0
  name             = "falco"
  repository       = "https://falcosecurity.github.io/charts"
  chart            = "falco"
  namespace        = "falco"
  create_namespace = true
  version          = "4.17.1"

  values = [
    yamlencode({
      falcosidekick = {
        enabled = true
        config = {
          webhook = {
            address = var.falco_webhook_url
          }
        }
      }
      customRules = {
        "voting-runtime-rules.yaml" = <<-EOT
        - rule: Shell Spawned In Voting Namespace
          desc: Detect shell spawned inside a voting namespace container
          condition: evt.type = execve and container and proc.cmdline contains "sh"
          output: Shell spawned in voting namespace (user=%user.name command=%proc.cmdline pod=%k8s.pod.name container=%container.name)
          priority: WARNING
          tags: [runtime, voting]
        EOT
      }
    })
  ]

  depends_on = [module.eks]
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
      description = "Voting application project"
      sourceRepos = [
        var.gitops_repo_url
      ]
      destinations = [
        {
          namespace = "voting"
          server    = "https://kubernetes.default.svc"
        },
        {
          namespace = "voting"
          name      = "devsecops-voting-aks"
        }
      ]
      clusterResourceWhitelist = [
        {
          group = ""
          kind  = "Namespace"
        },
        {
          group = "external-secrets.io"
          kind  = "ClusterSecretStore"
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

resource "kubernetes_manifest" "argocd_app_aws" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "voting-aws"
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
          valueFiles = ["values-prod.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "voting"
      }
      ignoreDifferences = [
        {
          group     = "apps"
          kind      = "Deployment"
          namespace = "voting"
          jsonPointers = [
            "/spec/template/spec/containers/0/image"
          ]
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
    kubernetes_namespace.voting,
    kubernetes_manifest.aws_secret_store,
  ]
}

resource "kubernetes_manifest" "argocd_app_azure" {
  count = var.enable_aks_spoke_registration ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "voting-azure-standby"
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
        name      = "devsecops-voting-aks"
        namespace = "voting"
      }
      syncPolicy = {
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_manifest.argocd_project_voting,
    kubernetes_secret.aks_cluster[0],
  ]
}
