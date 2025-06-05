output "AZURE_AKS_CLUSTER_NAME" {
  value = azurerm_kubernetes_cluster.example.name
}

output "AZURE_CONTAINER_REGISTRY_ENDPOINT" {
  value = azurerm_container_registry.example.login_server
}