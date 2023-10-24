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

variable "location" {
  description = "The Azure region where the resources reside in"
  type = string
}


# variable "environment" {
#   type = string
#   validation {
#     condition     = length(var.environment) <= 4
#     error_message = "The environment variable cannot be larger than 4 characters."
#   }
# }

variable "tags" {
  type = map(string)
  default     = {
    "Project"     = "Eck"
    "Org"         = "bgl"
  }
}

variable "subscription_id" {}

variable "client_id" {}

variable "client_secret" {}

variable "tenant_id" {}


# Virtual Network variables

# variable "vnet_name" {
#   description = "The name of the Virtual Network"
#   type = string
# }
variable "address_space" {
  description = "The address space that is used by the virtual network."
  type        = list(string)
}

variable "subnet_prefixes" {
  description = "The address prefixes to use for the subnets."
  type        = list(string)
}

variable "subnet_names" {
  description = "Names of the subnets within the VNet."
  type        = list(string)
}



# Aks variables
variable "k8s_version" { type = string }
variable "k8s_orchestrator_version" { type = string }
variable "k8s_node_count" { type = string }
variable "k8s_node_size" {
  type    = string
}