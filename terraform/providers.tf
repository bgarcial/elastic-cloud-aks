terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.82.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id

}

# Block to play around with the state if needed
terraform {
  backend "azurerm" {}
  # resource_group_name  = "pfc-terraform-envs-states"
  # storage_account_name = "pfcterraformstates"
  # container_name       = "pfcterraformstates"
  # key                  = "staging.terraform.tfstate"
  # }
}