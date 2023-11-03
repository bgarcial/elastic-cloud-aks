resource "azurerm_resource_group" "aks_rg" {
  name     = "eck-bgl-aks"
  location = var.aks_location
  tags     = local.tags
}

# resource "azurerm_log_analytics_workspace" "eck-monitor" {
#   name                = "eck-monitor-logs"
#   location            = azurerm_resource_group.aks_rg.location
#   resource_group_name = azurerm_resource_group.aks_rg.name
#   sku                 = "PerGB2018"
#   retention_in_days   = 30
# }

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}


module "azure_aks" {
  source                = "Azure/aks/azurerm"
  version               = "7.4.0"
  cluster_name          = local.kubernetes_cluster_name
  resource_group_name   = azurerm_resource_group.aks_rg.name
  prefix                = local.kubernetes_cluster_name #  dns_prefix
  kubernetes_version    = var.k8s_version
  log_analytics_workspace_enabled = true
  log_analytics_workspace_sku = "PerGB2018"
  log_retention_in_days = 30
  # cluster_log_analytics_workspace_name = azurerm_log_analytics_workspace.eck-monitor.name

  identity_type =  "SystemAssigned" 

  #  enable Azure AD-based Kubernetes service account token volume projection. 
  # This is a part of Azure AD Pod Identity, which allows you to bind Azure AD identities 
  # to Kubernetes service accounts. This feature provides Kubernetes Pods the ability to 
  # request and be assigned Azure AD-based identities, which can be used to interact with 
  # Azure services like Azure Key Vault, Azure SQL DB, etc., that understand Azure AD tokens.
  # Security: By associating a service account to an Azure AD identity, the Pod running as the 
  # service account will assume the Azure AD identity's permissions, enabling least-privilege access.
  # Simplified Token Management: The Azure AD tokens obtained are managed by the Kubernetes runtime; 
  # they are requested as needed and refreshed automatically.
  # Scoped Access: Because each service account can be associated with a different Azure AD identity, 
  # you can scope down permissions to only what that specific Pod requires to do its job, following the 
  # principle of least privilege.
  # Azure Services: These tokens can be used to access Azure services that understand Azure AD-based 
  # authentication, thereby reusing your existing identity setup in Azure.
  # This is a valuable feature for organizations looking to implement tight security controls on how 
  # their Kubernetes workloads interact with Azure services.
  # workload_identity_enabled = true
  oidc_issuer_enabled = true

  node_pools = {
    default_node_pool = {
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
        # vnet_subnet_id       = var.vnet_subnet_id
        # Code="InvalidParameter" Message="Cannot use a custom subnet because agent pool nodepool is 
        # using a managed subnet. Please omit the vnetSubnetID parameter from the re
        orchestrator_version = var.k8s_orchestrator_version
    }
    # another node pool
  }
  
  network_plugin     = "azure"
  load_balancer_sku = "standard"
  load_balancer_profile_enabled = true


  # will enable Azure AD-based Role-Based Access Control (RBAC) 
  # for your AKS cluster. This feature extends Kubernetes RBAC to 
  # integrate with Azure AD identities, so you can use Azure AD groups 
  # and user accounts to grant permissions within your Kubernetes cluster.
  # In a regular Kubernetes RBAC, you define roles and role bindings 
  # that use Kubernetes Service Accounts. When you enable Azure AD-based 
  # RBAC, you can define Kubernetes roles and role bindings that are 
  # associated directly with Azure AD identities (both users and groups). 
  # This enables more fine-grained control and governance over who can do what within your cluster.     
  rbac_aad = false # azure_active_directory_role_based_access_control on normal provisioner

  # Enable K8s native RBAC in the cluster
  role_based_access_control_enabled = true # rbac_enabled

  
  # This integrates Azure AD with Kubernetes RBAC. 
  # It allows you to use Azure AD identities for access to the 
  # Kubernetes API server. It's mostly used for user-level access 
  # azure_active_directory_role_based_access_control
  # When set to true, it enables Azure AD-based Role-Based Access Control (RBAC) 
  # for the AKS cluster. This feature integrates Azure AD groups and user accounts 
  # directly with Kubernetes RBAC.  
  # rbac_aad_azure_rbac_enabled = true # azure_rbac_enabled 


  # rbac_aad_managed: When this is set to true, it indicates that the Azure AD integration is managed by 
  # Azure itself. I won't need to specify the Azure AD client and server app details manually; 
  # Azure will manage those details for me. 
  # rbac_aad_managed   = true

  # vnet_subnet_id     = var.vnet_subnet_id
  
  # rbac_aad_tenant_id = var.tenant_id

  # log_analytics_workspace_id = azurerm_log_analytics_workspace.eck-monitor.id
  tags                       = var.tags
}


# resource "azurerm_kubernetes_cluster" "aks_main" {
#   name                = local.kubernetes_cluster_name
#   location            = var.aks_location
#   resource_group_name = azurerm_resource_group.aks_rg.name
#   dns_prefix          = local.kubernetes_cluster_name
#   kubernetes_version  = var.k8s_version
#   oms_agent {
#     log_analytics_workspace_id = azurerm_log_analytics_workspace.eck-monitor.id
#     msi_auth_for_monitoring_enabled = true
#   }
  
#   # api_server_authorized_ip_ranges = [
#   #   "213.127.120.249/24", # home ip address "${chomp(data.http.myip.response_body)}/32"
#   #   "40.74.28.0/23" # az devops runners
#   # ]

#   default_node_pool {
#     name                 = "default"
#     node_count           = var.k8s_node_count
#     vm_size              = var.k8s_node_size
#     zones   = ["1", "2", "3"]
#     enable_auto_scaling  = true
#     min_count            = 3
#     max_count            = 6
#     max_pods             = 250
#     os_disk_size_gb      = 128
#     os_sku               = "Ubuntu"
#     type                 = "VirtualMachineScaleSets"
#     vnet_subnet_id       = var.vnet_subnet_id
#     orchestrator_version = var.k8s_orchestrator_version
#   }

#   network_profile {
#     network_plugin    = "azure"
#     load_balancer_sku = "standard"
#   }

#   identity {
#     # This is for the AKS cluster itself to interact with other Azure 
#     # services. I can use a managed identity to allow the AKS cluster 
#     # to pull images from a private Azure Container Registry or to read 
#     # secrets from Azure Key Vault. 
#     type = "SystemAssigned"
#   }

#   # To enable or disable Kubernetes-native RBAC. 
#   # It's the basic form of access control within the cluster,
#   # based on Kubernetes roles and role bindings.
#   role_based_access_control_enabled = true

#   # This integrates Azure AD with Kubernetes RBAC. 
#   # It allows you to use Azure AD identities for access to the 
#   # Kubernetes API server. It's mostly used for user-level access 
#   # control to various resources in the Kubernetes cluster.
#   azure_active_directory_role_based_access_control {
#     managed = true
#     tenant_id = var.tenant_id
#     # admin_group_object_ids = [] # AAD groups
    
#     # will enable Azure AD-based Role-Based Access Control (RBAC) 
#     # for your AKS cluster. This feature extends Kubernetes RBAC to 
#     # integrate with Azure AD identities, so you can use Azure AD groups 
#     # and user accounts to grant permissions within your Kubernetes cluster.
#     # In a regular Kubernetes RBAC, you define roles and role bindings 
#     # that use Kubernetes Service Accounts. When you enable Azure AD-based 
#     # RBAC, you can define Kubernetes roles and role bindings that are 
#     # associated directly with Azure AD identities (both users and groups). This enables more fine-grained control and governance over who can do what within your cluster.
#     azure_rbac_enabled = true

#   # When managed is set to false the following properties can be specified:
#   #   client_id     = var.client_id
#   #   server_app_id     = var.server_app_id
#   #   server_app_secret = var.server_app_secret
#   # }
#   }

#   # Since I've specified Identity, service principal is not needed.
#   #  service_principal {
#   #    client_id     = var.azure_service_principal_client_id
#   #    client_secret = var.azure_service_principal_client_secret
#   #  }

#   tags = var.tags


#   # lifecycle {
#   #   ignore_changes = [
#   #     windows_profile,
#   #   ]
#   # }
# }
