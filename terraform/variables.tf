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

variable "subscription_id" {
    type = string
    default = "9148bd11-f32b-4b5d-a6c0-5ac5317f29ca"
}

variable "client_id" {
    type = string
    default = "15b673ac-a154-43e7-94d5-a293366d1dea"
}

variable "client_secret" {
    type = string
    default = "r6yJoSN4uRTH94RfDZcUnvUzzn_4cj6pia"
}

variable "tenant_id" {
    type = string
    default = "4e6b0716-50ea-4664-90a8-998f60996c44"
}


variable "k8s_version" { type = string }
variable "k8s_orchestrator_version" { type = string }
variable "k8s_node_count" { type = string }
variable "k8s_node_size" {
  type    = string
  default = "Standard_D4_v3"
}