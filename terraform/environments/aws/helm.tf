resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.7"

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = "$2b$10$wVFYNYEFx8ukoQAkG1MuoecZwKFUiMSVNZPCBEUhSnOrxT1LrU3Sm"
  }

  depends_on = [module.eks]
}

resource "helm_release" "sonarqube" {
  name             = "sonarqube"
  repository       = "https://SonarSource.github.io/helm-chart-sonarqube"
  chart            = "sonarqube"
  namespace        = "sonarqube"
  create_namespace = true

  set {
    name  = "community.enabled"
    value = "true"
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "monitoringPasscode"
    value = "define_it"
  }

  depends_on = [module.eks]
}

resource "time_sleep" "wait_for_argocd" {
  depends_on      = [helm_release.argocd]
  create_duration = "30s"
}

resource "null_resource" "argocd_app" {
  depends_on = [time_sleep.wait_for_argocd]

  triggers = {
    region       = var.aws_region
    cluster_name = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}
      kubectl apply -f ../k8s/argocd-app.yaml
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name}
      kubectl delete -f ../k8s/argocd-app.yaml --ignore-not-found=true
      sleep 20
    EOT
  }
}

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin123"
  }

  depends_on = [module.eks]
}
