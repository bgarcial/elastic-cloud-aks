variable "org" {
  type = string
  validation {
    condition     = length(var.org) <= 3
    error_message = "The org variable cannot be larger than 3 characters."
  }
}

variable "tenant" {
  type = string
  validation {
    condition     = length(var.tenant) <= 4
    error_message = "The tenant variable cannot be larger than 4 characters."
  }
}

variable "environment" {
  type = string
  validation {
    condition     = length(var.environment) <= 4
    error_message = "The environment variable cannot be larger than 4 characters."
  }
}

variable "k8s_version" { type = string }
variable "k8s_orchestrator_version" { type = string }
variable "k8s_node_count" { type = string }
variable "k8s_node_size" {
  type    = string
  default = "Standard_D4_v3"
}