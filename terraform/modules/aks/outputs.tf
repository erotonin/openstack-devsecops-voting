output "cluster_id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "host" {
  value     = azurerm_kubernetes_cluster.aks.kube_config[0].host
  sensitive = true
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive = true
}

output "client_key" {
  value     = azurerm_kubernetes_cluster.aks.kube_config[0].client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "kubelet_identity_object_id" {
  description = "Object ID kubelet identity (cho ACR Pull)"
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "kubelet_identity_client_id" {
  value = azurerm_kubernetes_cluster.aks.kubelet_identity[0].client_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer cho Workload Identity"
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}
