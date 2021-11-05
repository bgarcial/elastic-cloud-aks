resource "azurerm_resource_group" "eck-picnic" {
  name     = "eck-picnic-network"
  location = "West Europe"
}

resource "random_id" "id" {
  byte_length = 2
}

module "vnet" {
  source              = "Azure/vnet/azurerm"
  resource_group_name = azurerm_resource_group.eck-picnic.name
  address_space       = ["10.0.0.0/8"]
  subnet_prefixes     = ["10.1.0.0/16", "10.2.0.0/16"]
  subnet_names        = ["aks-subnet", "subnet"]

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


module "aks_name" {
  source   = "gsoft-inc/naming/azurerm//modules/general/resource_group"
  name     = "aks"
  prefixes = [var.org, var.app, var.environment]
}

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
  name                = module.aks_name.result
  depends_on          = [module.vnet]
  location            = azurerm_resource_group.aks-eck-picnic.location
  resource_group_name = azurerm_resource_group.aks-eck-picnic.name
  dns_prefix          = module.aks_name.result
  kubernetes_version  = var.k8s_version
  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.eck-monitor.id
    }
  }
  # api_server_authorized_ip_ranges = [
  #   "213.127.120.249/24", # home ip address "${chomp(data.http.myip.body)}/32"
  #   "40.74.28.0/23" # az devops runners
  # ]

  default_node_pool {
    name                 = "default"
    node_count           = var.k8s_node_count
    vm_size              = var.k8s_node_size
    availability_zones   = ["1", "2", "3"]
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
    load_balancer_sku = "Standard"
  }

  identity {
    type = "SystemAssigned"
  }
  role_based_access_control {
    enabled = true
    # azure_active_directory {
    # client_id     = var.client_id
    # server_app_id     = var.server_app_id
    # server_app_secret = var.server_app_secret
    # tenant_id         = var.tenant_id
    # }   
  }

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
