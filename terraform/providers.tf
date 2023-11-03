terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.79.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    random = {
      source = "hashicorp/random"
    }
    http = {
      source = "hashicorp/http"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id

}

provider "kubernetes" {
  host = data.azurerm_kubernetes_cluster.my-aks.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.my-aks.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.my-aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.my-aks.kube_config.0.cluster_ca_certificate)
  
  # If you're using Azure AD integration with AKS, you might need to specify the following instead:
  # load_config_file = false
  token = data.azurerm_kubernetes_cluster.my-aks.kube_config.token
}

# Block to play around with the state if needed
terraform {
  backend "azurerm" {
    resource_group_name  = "eck-terraform-envs-states"
    storage_account_name = "eckterraform"
    container_name       = "eck-tf-state"
    key                  = "staging.terraform.tfstate" 
  }
}
