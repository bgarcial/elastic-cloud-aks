output "resource_group_name" {
  value = module.aks.resource_group_name
}

output "resource_group_location" {
  value = module.aks.resource_group_location
}

output "aks_cluster_endpoint" {
  value = data.azurerm_kubernetes_cluster.my-aks.kube_config.0.host
  sensitive = true
}

output "aks_client_certificate" {
  value = base64decode(data.azurerm_kubernetes_cluster.my-aks.kube_config.0.client_certificate)
  sensitive = true
}

output "aks_client_key" {
  value = base64decode(data.azurerm_kubernetes_cluster.my-aks.kube_config.0.client_key)
  sensitive = true
}

output "aks_cluster_ca_certificate" {
  value = base64decode(data.azurerm_kubernetes_cluster.my-aks.kube_config.0.cluster_ca_certificate)
  sensitive = true
}

output "aks_cluster_id" {
  value = module.aks.cluster_id
  description = "The ID of the AKS cluster, exposed at the root level"
}

output "kubernetes_cluster_name" {
  value = module.aks.kubernetes_cluster_name
}

output "kube_fqdn" {
  value = module.aks.kube_fqdn
}

output "kube_admin_config_raw" {
  value     = module.aks.kube_admin_config_raw
  sensitive = true
}


output "kube_config_raw" {
  value     = module.aks.kube_config_raw
  sensitive = true
}

output "kube_client_certificate" {
  value = module.aks.kube_client_certificate
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
export MY_IP_ADDR="${chomp(data.http.myip.response_body)}/32"
EOF  
}