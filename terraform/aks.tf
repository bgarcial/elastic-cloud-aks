# Create Virtual Network
module "vnet" {
    source          = "./modules/vnet"
    vnet_location   = var.location
    address_space   = var.address_space
    subnet_prefixes = var.subnet_prefixes
    subnet_names    = var.subnet_names
    org             = var.org
    app             = var.app
    vnet_tags       =  var.tags
}


# Create kubernetes cluster.
module "aks" {
  source                    = "./modules/aks"
  aks_location              = var.location                                                      # The location.                                # The resource group.
  org                       = var.org
  app                       = var.app
  tags                      = var.tags
  vnet_id                   = module.vnet.vnet_id 
  vnet_subnet_id            = module.vnet.vnet_subnet_id
  k8s_version               = var.k8s_version
  k8s_orchestrator_version  = var.k8s_orchestrator_version
  k8s_node_count            = var.k8s_node_count
  k8s_node_size             = var.k8s_node_size
  tenant_id                 = var.tenant_id 
  # subnet_appgw        = azurerm_subnet.subnet_appgw.id                                    # The appgw subnet id.
  depends_on                = [module.vnet]
}