data "azurerm_kubernetes_cluster" "my-aks" {
  name                = module.aks.kubernetes_cluster_name
  resource_group_name = module.aks.resource_group_name
  depends_on = [ module.aks ]
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}