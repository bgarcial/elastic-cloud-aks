output "resource_group_name" {
  value = azurerm_resource_group.aks_rg.name
}

output "resource_group_location" {
  value = azurerm_resource_group.aks_rg.location
}

output "kubernetes_cluster_name" {
  value = module.azure_aks.aks_name
}

output "kube_fqdn" {
  value = module.azure_aks.cluster_fqdn
}

output "kube_admin_config_raw" {
  value     = module.azure_aks.kube_admin_config_raw
  sensitive = true
}


output "kube_config_raw" {
  value     = module.azure_aks.kube_config_raw
  sensitive = true
}

output "kube_client_certificate" {
  value = module.azure_aks.client_certificate
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
export MY_IP_ADDR="${chomp(data.http.myip.response_body)}/32"
EOF  
}