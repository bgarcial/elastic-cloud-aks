output "resource_group_name" {
  value = azurerm_resource_group.aks-eck-picnic.name
}

output "resource_group_location" {
  value = azurerm_resource_group.aks-eck-picnic.location
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.aks_main.name
}

output "kube_fqdn" {
  value = azurerm_kubernetes_cluster.aks_main.fqdn
}

output "vnet_subnet_id" {
  value = module.vnet.vnet_subnets[0]
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks_main.kube_config
  sensitive = true

}

output "kube_config_raw" {
  value     = azurerm_kubernetes_cluster.aks_main.kube_config_raw
  sensitive = true
}

output "kube_admin_config" {
  value     = azurerm_kubernetes_cluster.aks_main.kube_admin_config
  sensitive = true
}

output "kube_admin_config_raw" {
  value     = azurerm_kubernetes_cluster.aks_main.kube_admin_config_raw
  sensitive = true
}

output "configure" {
  value = <<CONFIGURE
Run the following commands to configure kubernetes client:
$ terraform output kube_config_raw > ~/.kube/config
$ export KUBECONFIG=~/.kube/config
Test configuration using kubectl
$ kubectl get nodes
CONFIGURE
}

output "my_ip_address" {
  value = <<EOF
export MY_IP_ADDR="${chomp(data.http.myip.body)}/32"
EOF  
}