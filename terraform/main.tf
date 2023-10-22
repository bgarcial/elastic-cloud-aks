resource "azurerm_resource_group" "eck-picnic" {
  name     = "eck-picnic-network"
  location = "West Europe"
}

resource "random_id" "id" {
  byte_length = 2
}

module "vnet" {
  source              = "Azure/vnet/azurerm"
  version             = "4.1.0"
  vnet_location       = azurerm_resource_group.aks-eck-picnic.location
  resource_group_name = azurerm_resource_group.eck-picnic.name
  address_space       = ["10.0.0.0/8"]
  subnet_prefixes     = ["10.1.0.0/16", "10.2.0.0/16"]
  subnet_names        = ["aks-subnet", "subnet"]
  use_for_each    = false

  # subnet_service_endpoints = {
  #   aks-subnet = ["Microsoft.Storage", "Microsoft.Sql"],
  # }

  tags = {
    environment = "staging"
  }

  depends_on = [azurerm_resource_group.eck-picnic]
}

resource "azurerm_resource_group" "aks-eck-picnic" {
  name     = "aks-eck-picnic"
  location = "West Europe"
}


# module "aks_name" {
#   source   = "gsoft-inc/naming/azurerm//modules/general/resource_group"
#   name     = "aks"
#   prefixes = [var.org, var.app, var.environment]
# }

resource "azurerm_log_analytics_workspace" "eck-monitor" {
  name                = "eck-monitor-logs"
  location            = azurerm_resource_group.aks-eck-picnic.location
  resource_group_name = azurerm_resource_group.aks-eck-picnic.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}

resource "azurerm_kubernetes_cluster" "aks_main" {
  name                = local.name
  depends_on          = [module.vnet]
  location            = azurerm_resource_group.aks-eck-picnic.location
  resource_group_name = azurerm_resource_group.aks-eck-picnic.name
  dns_prefix          = local.name
  kubernetes_version  = var.k8s_version
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.eck-monitor.id
    msi_auth_for_monitoring_enabled = true
  }
  
  # api_server_authorized_ip_ranges = [
  #   "213.127.120.249/24", # home ip address "${chomp(data.http.myip.response_body)}/32"
  #   "40.74.28.0/23" # az devops runners
  # ]

  default_node_pool {
    name                 = "default"
    node_count           = var.k8s_node_count
    vm_size              = var.k8s_node_size
    zones   = ["1", "2", "3"]
    enable_auto_scaling  = true
    min_count            = 3
    max_count            = 6
    max_pods             = 250
    os_disk_size_gb      = 128
    os_sku               = "Ubuntu"
    type                 = "VirtualMachineScaleSets"
    vnet_subnet_id       = module.vnet.vnet_subnets[0]
    orchestrator_version = var.k8s_orchestrator_version
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  identity {
    # This is for the AKS cluster itself to interact with other Azure 
    # services. I can use a managed identity to allow the AKS cluster 
    # to pull images from a private Azure Container Registry or to read 
    # secrets from Azure Key Vault. 
    type = "SystemAssigned"
  }

  # To enable or disable Kubernetes-native RBAC. 
  # It's the basic form of access control within the cluster,
  # based on Kubernetes roles and role bindings.
  role_based_access_control_enabled = true

  # This integrates Azure AD with Kubernetes RBAC. 
  # It allows you to use Azure AD identities for access to the 
  # Kubernetes API server. It's mostly used for user-level access 
  # control to various resources in the Kubernetes cluster.
  azure_active_directory_role_based_access_control {
    managed = true
    tenant_id = var.tenant_id
    # admin_group_object_ids = [] # AAD groups
    
    # will enable Azure AD-based Role-Based Access Control (RBAC) 
    # for your AKS cluster. This feature extends Kubernetes RBAC to 
    # integrate with Azure AD identities, so you can use Azure AD groups 
    # and user accounts to grant permissions within your Kubernetes cluster.
    # In a regular Kubernetes RBAC, you define roles and role bindings 
    # that use Kubernetes Service Accounts. When you enable Azure AD-based 
    # RBAC, you can define Kubernetes roles and role bindings that are 
    # associated directly with Azure AD identities (both users and groups). This enables more fine-grained control and governance over who can do what within your cluster.
    azure_rbac_enabled = true

  # When managed is set to false the following properties can be specified:
  #   client_id     = var.client_id
  #   server_app_id     = var.server_app_id
  #   server_app_secret = var.server_app_secret
  # }
  }

  # Since I've specified Identity, service principal is not needed.
  #  service_principal {
  #    client_id     = var.azure_service_principal_client_id
  #    client_secret = var.azure_service_principal_client_secret
  #  }

  tags = {
    Environment = "staging"
  }


  # lifecycle {
  #   ignore_changes = [
  #     windows_profile,
  #   ]
  # }
}
