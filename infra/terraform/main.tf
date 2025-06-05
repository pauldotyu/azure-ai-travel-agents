terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.31.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "=2.37.1"
    }
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
  host                   = azurerm_kubernetes_cluster.example.kube_config.0.host
  username               = azurerm_kubernetes_cluster.example.kube_config.0.username
  password               = azurerm_kubernetes_cluster.example.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
}


resource "random_integer" "example" {
  min = 100
  max = 999
}

resource "azurerm_resource_group" "example" {
  name     = "rg-${var.environment}"
  location = var.location
}

resource "azurerm_container_registry" "example" {
  name                = "acr${lower(replace(var.environment, "/[^a-zA-Z0-9]/", ""))}${random_integer.example.result}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard"
}

resource "azurerm_kubernetes_cluster" "example" {
  name                      = "aks-${var.environment}${random_integer.example.result}"
  location                  = azurerm_resource_group.example.location
  resource_group_name       = azurerm_resource_group.example.name
  dns_prefix                = "aks-${var.environment}${random_integer.example.result}"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_D2_v4"

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }


}

resource "azurerm_role_assignment" "example1" {
  principal_id                     = azurerm_kubernetes_cluster.example.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.example.id
  skip_service_principal_aad_check = true
}

resource "azurerm_ai_services" "example" {
  resource_group_name          = azurerm_resource_group.example.name
  location                     = azurerm_resource_group.example.location
  name                         = "cog-${var.environment}${random_integer.example.result}"
  custom_subdomain_name        = "cog-${var.environment}${random_integer.example.result}"
  sku_name                     = "S0"
  local_authentication_enabled = false
}

resource "azurerm_cognitive_deployment" "example1" {
  cognitive_account_id = azurerm_ai_services.example.id
  name                 = "gpt-4o-mini"

  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 8
  }
}

resource "azurerm_cognitive_deployment" "example2" {
  cognitive_account_id = azurerm_ai_services.example.id
  name                 = "text-embedding-3-large"

  model {
    format  = "OpenAI"
    name    = "text-embedding-3-large"
    version = "1"
  }

  sku {
    name     = "Standard"
    capacity = 10
  }
}

resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "id-${var.environment}${random_integer.example.result}"
}

resource "azurerm_federated_identity_credential" "example" {
  resource_group_name = azurerm_resource_group.example.name
  parent_id           = azurerm_user_assigned_identity.example.id
  name                = "${azurerm_ai_services.example.name}-k8s"
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  audience            = ["api://AzureADTokenExchange"]
  subject             = "system:serviceaccount:default:travelagent"
}

resource "azurerm_role_assignment" "example2" {
  scope                = azurerm_ai_services.example.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.example.principal_id
}

resource "kubernetes_service_account_v1" "example" {
  metadata {
    name = "travelagent"
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.example.client_id
    }
  }
}
