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


variable "vnet_location" {
  description = "The location of the VNet"
  type        = string
}

variable "vnet_tags" {
  type = map(string)
}

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