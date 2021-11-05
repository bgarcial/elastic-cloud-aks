variable "org" {
  type = string
  validation {
    condition     = length(var.org) <= 3
    error_message = "The org variable cannot be larger than 3 characters."
  }
}

variable "app" {
  type = string
  validation {
    condition     = length(var.app) <= 4
    error_message = "The app variable cannot be larger than 4 characters."
  }
}

variable "environment" {
  type = string
  validation {
    condition     = length(var.environment) <= 4
    error_message = "The environment variable cannot be larger than 4 characters."
  }
}

variable "subscription_id" {}

variable "client_id" {}

variable "client_secret" {}

variable "tenant_id" {}


variable "k8s_version" { type = string }
variable "k8s_orchestrator_version" { type = string }
variable "k8s_node_count" { type = string }
variable "k8s_node_size" {
  type    = string
  default = "Standard_D4_v3"
}