variable "org" {
  type = string
  validation {
    condition     = length(var.org) <= 3
    error_message = "The org variable cannot be larger than 3 characters!"
  }
}

variable "app" {
  type = string
  validation {
    condition     = length(var.app) <= 4
    error_message = "The app variable cannot be larger than 4 characters."
  }
}

variable "aks_location" {
  description = "The location of the AKS cluster"
  type        = string
}

variable "k8s_version" { type = string }
variable "k8s_orchestrator_version" { type = string }
variable "k8s_node_count" { type = string }
variable "k8s_node_size" { type  = string }

variable "vnet_id" {
  description = "VNet ID"
  type        = string
}

variable "vnet_subnet_id" {
  description = "VNet Subnet ID"
  type        = string
}



variable "tenant_id" {}

variable "tags" {
  type = map(string)
}