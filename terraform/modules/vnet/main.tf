resource "azurerm_resource_group" "vnet_rg" {
  name     = "eck-bgl-network"
  location = var.vnet_location
  tags     = local.tags
}

module "vnet" {
  source              = "Azure/vnet/azurerm"
  version             = "4.1.0"
  vnet_name           = local.virtual_network_name
  vnet_location       = azurerm_resource_group.vnet_rg.location
  resource_group_name = azurerm_resource_group.vnet_rg.name
  address_space       = var.address_space
  subnet_prefixes     = var.subnet_prefixes
  subnet_names        = var.subnet_names
  use_for_each        = false

  # subnet_service_endpoints = {
  #   aks-subnet = ["Microsoft.Storage", "Microsoft.Sql"],
  # }

  tags = local.tags

  depends_on = [azurerm_resource_group.vnet_rg]
}