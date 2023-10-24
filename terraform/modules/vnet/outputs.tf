output "vnet_id" {
  value = module.vnet.vnet_id
  description = "The ID of the Virtual Network."
}

output "vnet_subnet_id" {
  value = module.vnet.vnet_subnets[0]
}

output "vnet_location" {
  value = module.vnet.vnet_location
  description = "The location of the Virtual Network."
}
